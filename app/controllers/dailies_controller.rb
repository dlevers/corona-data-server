require 'csv'

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


    @populationCountries    = {}
    @populationUSStates     = {}
    @populationUSFLCounties = {}

    populationDataPathBase = ENV[ 'DLE_CORONA_POPULATIONDATA_PATH' ] || "/Users/dlevers/Src/Sandbox/Corona/corona-data-server/data/Population"
    puts "index: populationDataPathBase=" + populationDataPathBase
    Dir.foreach( populationDataPathBase ) do |filename|
      next if filename == '.' or filename == '..'

      dest  = nil
      case filename
      when 'PopulationCountries202004.csv'
        dest = 'countries'
      when 'PopulationUSStates202004.csv'
        dest = 'states'
      when 'PopulationUS-FLCounties202004.csv'
        dest = 'counties'
      else
        puts "index: UNKNOWN population data filename=" + filename
      end

      unless dest.nil?
        CSV.foreach(File.join(populationDataPathBase, filename), :headers => true) do |row|
          # Moulding.create!(row.to_hash)
          # puts "index: dest=" + dest + "  row=" + row.to_hash.to_s
          case dest
          when 'countries'
            @populationCountries[row.to_hash["Country"]]  = row.to_hash
          when 'states'
            @populationUSStates[row.to_hash["State"]]     = row.to_hash
          when 'counties'
            @populationUSFLCounties[row.to_hash["County"]]     = row.to_hash
          end
        end
      end
    end
    puts "index: Countries=" + @populationCountries.to_s
    puts "index: USStates=" + @populationUSStates.to_s
    puts "index: US-FLCounties=" + @populationUSFLCounties.to_s

    if @parentTerritory == "world"
      @populationToUse = @populationCountries
    elsif @parentTerritory == "US"
      @populationToUse = @populationUSStates
    elsif @parentTerritory == "Florida"
      @populationToUse = @populationUSFLCounties
    else
      @populationToUse = {}
    end
  end
end
