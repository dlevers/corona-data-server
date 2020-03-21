class WelcomeController < ApplicationController
  KExpectedDatestringLength = 10
  KTerritoryWorld           = "world"

  def index
    dataPathBase  = "/Users/dlevers/Src/Sandbox/Coronavirus19/data/JohnsHopkinsPipedream/"
    # fileName      = "2020-03-20-13.22.json"
    #allSummary  = { "Confirmed" => 0 }
    allSummaryConfirmed = 0

    Dir.foreach( dataPathBase ) do |filename|
      next if filename == '.' or filename == '..'

      # Do work on the remaining files & directories
      dateString    = dateFromFilename( filename )
      puts "index: dateString=" + dateString
      if dateString.length == KExpectedDatestringLength
        # Valid, keep going
        dailies = Daily.find_by( :date => dateString )
        if !dailies
          puts "index: keep for ZERO dailies.length"
          #allSummary[ "Confirmed" ] += indexOneFile( dataPathBase, filename )
          allSummaryConfirmed = indexOneFile( dateString, dataPathBase, filename )
          puts "index: allSummaryConfirmed=" + allSummaryConfirmed.to_s
        else
          puts "index: SKIP for existing dailies"
        end
      else
        puts "index: ERROR dateString=" + dateString
      end
    end

    puts "---"
    puts "allSummary.Confirmed=" + allSummaryConfirmed.to_s
  end


  private

  def dateFromFilename( filenameIn )
    dateString  = filenameIn[ 0...10 ]
    testString  = filenameIn[ /....-..-../ ]
    puts "dateFromFilename: dateString=" + dateString + "  testString=" + testString

    if dateString.eql?( testString )
      return dateString
    end

    return nil
  end


  def indexOneFile( datestringIn, pathIn, filenameIn )
    fjs = File.read( pathIn + filenameIn )
    ojs = JSON.parse( fjs )

    totals  = { "Confirmed" => 0,
                "Recovered" => 0,
                "Deaths" => 0 }

    puts "pathIn:        " + pathIn
    puts "filenameIn:    " + filenameIn
    # puts "apiSourceCode: " + ojs[ "apiSourceCode" ]
    # puts "entry count:   " + ojs[ "rawData" ].length.to_s
    countrySummaries  = {}

    puts "---"
    puts "standalone countries"
    ojs[ "rawData" ].each do |oneRawValue|
      if oneRawValue[ "Province/State" ].length > 0
        if countrySummaries.key?( oneRawValue[ "Country/Region" ])
          countrySummaries[ oneRawValue[ "Country/Region" ]][ "Confirmed" ] += oneRawValue[ "Confirmed" ].to_i
          countrySummaries[ oneRawValue[ "Country/Region" ]][ "Recovered" ] += oneRawValue[ "Recovered" ].to_i
          countrySummaries[ oneRawValue[ "Country/Region" ]][ "Deaths" ]    += oneRawValue[ "Deaths" ].to_i

          oldLatitude = countrySummaries[ oneRawValue[ "Country/Region" ]][ "Latitude" ]
          latitude    = oldLatitude * countrySummaries[ oneRawValue[ "Country/Region" ]][ "count" ] + oneRawValue[ "Latitude" ].to_f
          newLatitude = latitude / ( countrySummaries[ oneRawValue[ "Country/Region" ]][ "count" ] + 1 )
          countrySummaries[ oneRawValue[ "Country/Region" ]][ "Latitude" ]   = newLatitude
          oldLongitude  = countrySummaries[ oneRawValue[ "Country/Region" ]][ "Longitude" ]
          longitude     = oldLongitude * countrySummaries[ oneRawValue[ "Country/Region" ]][ "count" ] + oneRawValue[ "Longitude" ].to_f
          newLongitude = longitude / ( countrySummaries[ oneRawValue[ "Country/Region" ]][ "count" ] + 1 )
          countrySummaries[ oneRawValue[ "Country/Region" ]][ "Longitude" ]  = newLongitude

          countrySummaries[ oneRawValue[ "Country/Region" ]][ "count" ]     += 1
          puts "indexOneFile: country,state=" + oneRawValue[ "Country/Region" ] + "," + oneRawValue[ "Province/State" ] + "  old lat,long=" + oldLatitude.to_s + "," +
                oldLongitude.to_s + "  count=" + countrySummaries[ oneRawValue[ "Country/Region" ]][ "count" ].to_s + "  new lat,long=" + newLatitude.to_s + "," + newLongitude.to_s
        else
          countrySummaries[ oneRawValue[ "Country/Region" ]] = { "count" => 1,
                                                                "Confirmed" => oneRawValue[ "Confirmed" ].to_i,
                                                                "Recovered" => oneRawValue[ "Recovered" ].to_i,
                                                                "Deaths" => oneRawValue[ "Deaths" ].to_i,
                                                                "Latitude" => oneRawValue[ "Latitude" ].to_f,
                                                                "Longitude" => oneRawValue[ "Longitude" ].to_f }
        end
        @daily  = Daily.new( :date => datestringIn, :territory => oneRawValue[ "Province/State" ], :territoryparent => oneRawValue[ "Country/Region" ],
                          :summary => false, :confirmed => oneRawValue[ "Confirmed" ], :recovered => oneRawValue[ "Recovered" ],
                          :deaths => oneRawValue[ "Deaths" ], :latitude => oneRawValue[ "Latitude" ].to_f, :longitude => oneRawValue[ "Longitude" ].to_f )
      else
        # puts "one.Country/Region=" + oneRawValue[ "Country/Region" ] + "  confirmed=" + oneRawValue[ "Confirmed" ]
        #totalConfirmed  += oneRawValue[ "Confirmed" ].to_i
        @daily  = Daily.new( :date => datestringIn, :territory => oneRawValue[ "Country/Region" ], :territoryparent => KTerritoryWorld,
                          :summary => false, :confirmed => oneRawValue[ "Confirmed" ], :recovered => oneRawValue[ "Recovered" ],
                          :deaths => oneRawValue[ "Deaths" ], :latitude => oneRawValue[ "Latitude" ].to_f, :longitude => oneRawValue[ "Longitude" ].to_f )

        totals[ "Confirmed" ] += oneRawValue[ "Confirmed" ].to_i
        totals[ "Recovered" ] += oneRawValue[ "Recovered" ].to_i
        totals[ "Deaths" ]    += oneRawValue[ "Deaths" ].to_i
      end

      @daily.save
    end

    # Now for all those that saw accumulated province/state(s)
    puts "---"
    puts "indexOneFile: countries with provinces/states"
    countrySummaries.each do |oneKey, oneValue|
      puts "indexOneFile: one.accumulated.Country/Region=" + oneKey + " total confirmed=" + countrySummaries[ oneKey ][ "Confirmed" ].to_s

      @daily  = Daily.new( :date => datestringIn, :territory => oneKey, :territoryparent => KTerritoryWorld, :summary => true, :confirmed => oneValue[ "Confirmed" ].to_s,
                          :recovered => oneValue[ "Recovered" ].to_s, :deaths => oneValue[ "Deaths" ].to_s, :latitude => oneValue[ "Latitude" ],
                          :longitude => oneValue[ "Longitude" ] )
      @daily.save

      # totalConfirmed += countrySummaries[ oneKey ][ "Confirmed" ]
      totals[ "Confirmed" ] += countrySummaries[ oneKey ][ "Confirmed" ]
      totals[ "Recovered" ] += countrySummaries[ oneKey ][ "Recovered" ]
      totals[ "Deaths" ]    += countrySummaries[ oneKey ][ "Deaths" ]
    end

    puts "indexOneFile: totals.Confirmed,Recovered,Deaths=" + totals[ "Confirmed" ].to_s + "," + totals[ "Recovered" ].to_s + "," + totals[ "Deaths" ].to_s
    @daily  = Daily.new( :date => datestringIn, :territory => KTerritoryWorld, :territoryparent => "(none)", :summary => true, :confirmed => totals[ "Confirmed" ].to_s,
                        :recovered => totals[ "Recovered" ].to_s, :deaths => totals[ "Deaths" ].to_s, :latitude => 0.0, :longitude => 0.0 )
    @daily.save

    return totals[ "Confirmed" ]
  end
end
