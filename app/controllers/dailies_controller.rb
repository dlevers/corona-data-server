class DailiesController < ApplicationController
  def show
    daily = Daily.find( params[ :id ])
    puts "show: daily.territory=" + daily.territory
    @parentTerritory = daily.territory

    @dailies = Daily.where( :territoryparent => daily.territory )

    allTerritoriesWithCounts  = {}
    @dailies.each do |oneDaily|
      # if countrySummaries.key?( oneRawValue[ "Country/Region" ])
      if allTerritoriesWithCounts.key?( oneDaily.territory )
        if oneDaily.confirmed.to_i > allTerritoriesWithCounts[ oneDaily.territory ]
          allTerritoriesWithCounts[ oneDaily.territory ] = oneDaily.confirmed.to_i
        end
      else
        allTerritoriesWithCounts[ oneDaily.territory ]  = oneDaily.confirmed.to_i
        #allTerritoriesWithCounts.append({ "territory" => oneDaily.territory, "confirmed" => oneDaily.confirmed.to_i })
      end
    end
    #allTerritoriesWithCounts.sort_by{ |obj| obj[ "confirmed" ]}.reverse
    sortedTerritoriesWithCounts  = allTerritoriesWithCounts.sort_by{ |k, v| -v }.to_h

    # allTerritories  = []
    # allTerritoriesWithCounts.each_key do |oneCountKey|
    #   #allTerritories.append( oneWithCounts[ "territory" ])
    #   allTerritories.append( oneCountKey )
    # end

    #@uTerritories = allTerritories.uniq()
    @uTerritories = sortedTerritoriesWithCounts.keys.uniq
  end
end
