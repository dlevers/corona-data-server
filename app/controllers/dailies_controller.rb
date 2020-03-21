class DailiesController < ApplicationController
  def show
    @daily = Daily.find( params[ :id ])
    puts "show: daily.territory=" + @daily.territory

    @dailies = Daily.where( :territoryparent => @daily.territory )
  end
end
