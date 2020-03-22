class DailiesController < ApplicationController
  def show
    daily = Daily.find( params[ :id ])
    puts "show: daily.territory=" + daily.territory
    @parentTerritory = daily.territory

    @dailies = Daily.where( :territoryparent => daily.territory )

    allTerritoriesWithCounts  = {}
    @dailies.each do |oneDaily|
      if allTerritoriesWithCounts.key?( oneDaily.territory )
        if oneDaily.confirmed.to_i > allTerritoriesWithCounts[ oneDaily.territory ]
          allTerritoriesWithCounts[ oneDaily.territory ] = oneDaily.confirmed.to_i
        end
      else
        allTerritoriesWithCounts[ oneDaily.territory ]  = oneDaily.confirmed.to_i
      end
    end
    sortedTerritoriesWithCounts  = allTerritoriesWithCounts.sort_by{ |k, v| -v }.to_h

    @uTerritories = sortedTerritoriesWithCounts.keys.uniq
  end
end
