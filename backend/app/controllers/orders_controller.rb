class OrdersController < ApplicationController
  skip_before_action :verify_authenticity_token

  def index
    response = CoinGateService.get_orders
    response.success? ? success_response(response.parsed_response) : external_service_error_response
  end

  def new
    @order = Order.new
  end
  

  def create
    @order = Order.new(order_params)
    
    if @order.save
      CoinGateService.new(@order).create_order
      render json: {}, status: :ok
    else
      head 500
    end
  end

  def show
    @order = Order.find_by(coingate_order_id: params[:id])
    response = CoinGateService.new(@order).get_order
    response.success? ? success_response(response.parsed_response) : external_service_error_response
  end

  def currencies
    response = CoinGateService.get_currencies
    response.success? ? success_response(response.parsed_response) : external_service_error_response
  end

  def get_order
    @order = Order.find_by(coingate_order_id: params[:id])
    response = CoinGateService.new(@order).get_order
    response.success? ? success_response(response.parsed_response) : external_service_error_response
  end

  def cancel_order
    response = @coingate_service.cancel_order(params[:id])
    response.success? ? success_response(response.parsed_response) : external_service_error_response
  end

  def callback
    order = Order.find_by(payment_processor_order_id: params[:payment_processor_order_id])
    order ? success_response(order.update(status: params[:status])) : not_found_response
  end

  private

  def order_params
    params.require(:order).permit(
      :order_id,
      :price_amount,
      :price_currency,
      :receive_currency,
      :title,
      :description,
      :purchaser_email
    )
  end
  
  def callback_urls
    {
      callback_url: Rails.configuration.coingate_callback_url,
      cancel_url: Rails.configuration.coingate_cancel_url,
      success_url: Rails.configuration.coingate_success_url
    }
  end

  def save_order(order_attributes)
    @order = Order.new(order_attributes)
    @order.save ? @order : nil
  end

  def extract_order_attributes(api_response)
    api_response.slice('payment_processor_order_id', 'price_amount', 'price_currency', 'receive_currency', 'title', 'description', 'purchaser_email')
  end

  def success_response(data)
    render json: data, status: :ok
  end

  def failure_response(order)
    render json: { message: order.errors.full_messages }, status: :unprocessable_entity
  end

  def external_service_error_response
    render json: { message: 'Failed to communicate with CoinGate' }, status: :internal_server_error
  end

  def not_found_response
    render json: { message: 'Order not found' }, status: :not_found
  end

end