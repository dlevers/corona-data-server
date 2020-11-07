class RatesController < ApplicationController
  def show
    daily = Daily.find( params[ :id ])
    puts "RatesController.show: daily.territory=" + daily.territory
  end
end
