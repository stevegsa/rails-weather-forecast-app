# app/controllers/forecasts_controller.rb
#
# Handles address input and delegates to the forecast use case.

class ForecastsController < ApplicationController
  # Renders the address form.
  def new; end

  # Validates the address, calls the use case, and re-renders the same view.
  def create
    @address = params[:address].to_s.strip

    if @address.blank?
      flash.now[:alert] = 'Please enter an address.'
      return render :new
    end

    @detailed_forecast = Forecasts::FetchByAddress.new.call(@address)
    @forecast          = @detailed_forecast.forecast

    render :new
  rescue Forecasts::FetchByAddress::Error => e
    flash.now[:alert] = e.message
    render :new
  end
end
