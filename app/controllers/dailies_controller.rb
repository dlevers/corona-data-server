class DailiesController < ApplicationController
  def show
    daily = Daily.find( params[ :id ])
    puts "show: daily.territory=" + daily.territory
    @parentTerritory = daily.territory

    @dailies = Daily.where( :territoryparent => daily.territory )

    allTerritories  = []
    @dailies.each do |oneDaily|
        allTerritories.append( oneDaily.territory )
    end
    @uTerritories = allTerritories.uniq()
  end
end
