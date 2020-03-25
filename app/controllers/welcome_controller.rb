class WelcomeController < ApplicationController
  KExpectedDatestringLength = 10
  KTerritoryWorld           = "world"
  KKeyCountryRegionA        = "Country/Region"
  KKeyProvinceStateA        = "Province/State"
  KKeyLatitudeA             = "Latitude"
  KKeyLongitudeA            = "Longitude"
  # 2020-03-24  Format changed - including a new Admin2, which appears to be counties for US states
  KKeyCountryRegionB        = "Country_Region"
  KKeyProvinceStateB        = "Province_State"
  KKeyLatitudeB             = "Lat"
  KKeyLongitudeB            = "Long_"
  KKeyAdmin2b               = "Admin2"

  def index
    dataPathBase  = ENV[ 'DLE_CORONA_SOURCEDATA_PATH' ] || "/Users/dlevers/Src/Sandbox/Coronavirus19/data/JohnsHopkinsPipedream/"
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
          allSummaryConfirmed = indexOneFile( dateString, dataPathBase, filename )
          puts "index: allSummaryConfirmed=" + allSummaryConfirmed.to_s
        else
          puts "index: SKIP for existing dailies"
        end
      else
        puts "index: ERROR dateString=" + dateString
      end
    end

    puts "index: allSummary.Confirmed=" + allSummaryConfirmed.to_s
  
    @dailies = Daily.all
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
    fjs = File.read( File.join( pathIn, filenameIn ))
    ojs = JSON.parse( fjs )

    puts "indexOneFile: pathIn:        " + pathIn
    puts "indexOneFile: filenameIn:    " + filenameIn
    @stateSummaries   = {}
    @countrySummaries = {}
    @worldTotals  = { "Confirmed" => 0,
                    "Recovered" => 0,
                    "Deaths" => 0 }

    # Process every record for the giving datestring (corresponding to an input JSON file).
    ojs[ "rawData" ].each do |oneRawValue|
      versionedFields = { KKeyCountryRegionA => "",
                        KKeyProvinceStateA => "",
                        KKeyAdmin2b => "",
                        KKeyLatitudeA => 0.0,
                        KKeyLongitudeA => 0.0 }

      # Extract values from keys that have changed name over time
      if oneRawValue.key?( KKeyCountryRegionA )
        versionedFields[ KKeyCountryRegionA ] = oneRawValue[ KKeyCountryRegionA ]
      elsif oneRawValue.key?( KKeyCountryRegionB )
        versionedFields[ KKeyCountryRegionA ] = oneRawValue[ KKeyCountryRegionB ]
      else
        puts "indexOneFile: UNKNOWN KKeyCountryRegion in oneRawValue - " + oneRawValue.to_s
      end

      if oneRawValue.key?( KKeyProvinceStateA )
        versionedFields[ KKeyProvinceStateA ] = oneRawValue[ KKeyProvinceStateA ]
      elsif oneRawValue.key?( KKeyProvinceStateB )
        versionedFields[ KKeyProvinceStateA ] = oneRawValue[ KKeyProvinceStateB ]
      else
        puts "indexOneFile: UNKNOWN keyProvinceState in oneRawValue - " + oneRawValue.to_s
      end

      vAdmin2 = ""
      if oneRawValue.key?( KKeyAdmin2b )
        versionedFields[ KKeyAdmin2b ]  = oneRawValue[ KKeyAdmin2b ]
      end

      if oneRawValue.key?( KKeyLatitudeA )
        versionedFields[ KKeyLatitudeA ]  = oneRawValue[ KKeyLatitudeA ]
      elsif oneRawValue.key?( KKeyLatitudeB )
        versionedFields[ KKeyLatitudeA ]  = oneRawValue[ KKeyLatitudeB ]
      else
        puts "indexOneFile: UNKNOWN KKeyLatitude in oneRawValue - " + oneRawValue.to_s
      end

      if oneRawValue.key?( KKeyLongitudeA )
        versionedFields[ KKeyLongitudeA ]  = oneRawValue[ KKeyLongitudeA ]
      elsif oneRawValue.key?( KKeyLongitudeB )
        versionedFields[ KKeyLongitudeA ]  = oneRawValue[ KKeyLongitudeB ]
      else
        puts "indexOneFile: UNKNOWN KKeyLongitude in oneRawValue - " + oneRawValue.to_s
      end

      # Sometimes we see some entries with State and Country equal, like this ...:
      #   {
      #     "Province/State":"US",
      #     "Country/Region":"US",
      #     "Last Update":"2020-03-19T19:13:18",
      #     "Confirmed":"1",
      #     "Deaths":"0",
      #     "Recovered":"108",
      #     "Latitude":"37.0902",
      #     "Longitude":"-95.7129"
      #  },
      # ... so fix up the Province in this case.  Else we save off a territory that matches a country when it should be
      # a state, and other things break down.
      if versionedFields[ KKeyCountryRegionA ] == versionedFields[ KKeyProvinceStateA ]
        versionedFields[ KKeyProvinceStateA ] = versionedFields[ KKeyProvinceStateA ] + "_ProvSt"
        puts "indexOneFile: fixup KKeyProvinceStateA to " + versionedFields[ KKeyProvinceStateA ]
      end

      # index the data at its smallest geographics area (county, state, country)
      @daily  = nil
      if versionedFields[ KKeyAdmin2b ].length > 0
        @daily  = indexOnAdmin2( datestringIn, versionedFields, oneRawValue )
      elsif versionedFields[ KKeyProvinceStateA ].length > 0
        @daily  = indexOnProvinceState( datestringIn, versionedFields, oneRawValue )
      else
        @daily  = indexOnCountryRegion( datestringIn, versionedFields, oneRawValue )
      end

      # save the record formatted for our db
      @daily.save
    end

    # Above indexing on counties produces stateSummaries that we can now push to our db
    puts "indexOneFile: states with counties"
    @stateSummaries.each do |oneKey, oneValue|
      puts "indexOneFile: one.accumulated.state=" + oneKey + " total confirmed=" + @stateSummaries[ oneKey ][ "Confirmed" ].to_s

      @daily  = Daily.new( :date => datestringIn, :territory => oneKey, :territoryparent => oneValue[ "Parent" ], :summary => true, :confirmed => oneValue[ "Confirmed" ].to_s,
                          :recovered => oneValue[ "Recovered" ].to_s, :deaths => oneValue[ "Deaths" ].to_s, :latitude => oneValue[ "Latitude" ],
                          :longitude => oneValue[ "Longitude" ] )
      @daily.save

      # the stateSummaries produced from indexing on counties are not yet counted in their parent countries; do that here
      accumulateOnState( datestringIn, oneKey, oneValue )
    end

    # Summarize accumulated countries
    puts "indexOneFile: countries with provinces/states"
    @countrySummaries.each do |oneKey, oneValue|
      puts "indexOneFile: datestringIn=" + datestringIn + "  one.accumulated.Country/Region=" + oneKey + " total confirmed=" + @countrySummaries[ oneKey ][ "Confirmed" ].to_s

      # United Kingdom and Netherlands appear to have both standalone summary records and sub-territory records, so
      # prefer the (already saved) summary if it is there
      existing  = Daily.find_by( :date => datestringIn, :territory => oneKey )
      if existing
        puts "indexOneFile: in countrySummaries, SKIP for existing datestringIn=" + datestringIn + "  territory=" + oneKey + "  existing=" + existing.to_s
      else
        @daily  = Daily.new( :date => datestringIn, :territory => oneKey, :territoryparent => KTerritoryWorld, :summary => true, :confirmed => oneValue[ "Confirmed" ].to_s,
                            :recovered => oneValue[ "Recovered" ].to_s, :deaths => oneValue[ "Deaths" ].to_s, :latitude => oneValue[ "Latitude" ],
                            :longitude => oneValue[ "Longitude" ] )
        @daily.save

        @worldTotals[ "Confirmed" ] += @countrySummaries[ oneKey ][ "Confirmed" ]
        @worldTotals[ "Recovered" ] += @countrySummaries[ oneKey ][ "Recovered" ]
        @worldTotals[ "Deaths" ]    += @countrySummaries[ oneKey ][ "Deaths" ]
      end
    end

    # Summarize the world
    @daily  = Daily.new( :date => datestringIn, :territory => KTerritoryWorld, :territoryparent => "(none)", :summary => true, :confirmed => @worldTotals[ "Confirmed" ].to_s,
                        :recovered => @worldTotals[ "Recovered" ].to_s, :deaths => @worldTotals[ "Deaths" ].to_s, :latitude => 0.0, :longitude => 0.0 )
    @daily.save
  end


  def indexOnAdmin2( datestringIn, versionedFieldsIn, rawDataIn )
    if @stateSummaries.key?( versionedFieldsIn[ KKeyProvinceStateA ])
      @stateSummaries[ versionedFieldsIn[ KKeyProvinceStateA ]][ "Confirmed" ] += rawDataIn[ "Confirmed" ].to_i
      @stateSummaries[ versionedFieldsIn[ KKeyProvinceStateA ]][ "Recovered" ] += rawDataIn[ "Recovered" ].to_i
      @stateSummaries[ versionedFieldsIn[ KKeyProvinceStateA ]][ "Deaths" ]    += rawDataIn[ "Deaths" ].to_i

      oldLatitude = @stateSummaries[ versionedFieldsIn[ KKeyProvinceStateA ]][ KKeyLatitudeA ]

      latitude      = oldLatitude * @stateSummaries[ versionedFieldsIn[ KKeyProvinceStateA ]][ "count" ] + versionedFieldsIn[ KKeyLatitudeA ].to_f
      newLatitude   = latitude / ( @stateSummaries[ versionedFieldsIn[ KKeyProvinceStateA ]][ "count" ] + 1 )
      @stateSummaries[ versionedFieldsIn[ KKeyProvinceStateA ]][ KKeyLatitudeA ]   = newLatitude
      oldLongitude  = @stateSummaries[ versionedFieldsIn[ KKeyProvinceStateA ]][ KKeyLongitudeA ]
      longitude     = oldLongitude * @stateSummaries[ versionedFieldsIn[ KKeyProvinceStateA ]][ "count" ] + versionedFieldsIn[ KKeyLongitudeA ].to_f
      newLongitude  = longitude / ( @stateSummaries[ versionedFieldsIn[ KKeyProvinceStateA ]][ "count" ] + 1 )
      @stateSummaries[ versionedFieldsIn[ KKeyProvinceStateA ]][ KKeyLongitudeA ]  = newLongitude

      @stateSummaries[ versionedFieldsIn[ KKeyProvinceStateA ]][ "count" ]     += 1
      puts "indexOneFile: country,state=" + versionedFieldsIn[ KKeyProvinceStateA ] + "," + versionedFieldsIn[ KKeyProvinceStateA ] + "  old lat,long=" + oldLatitude.to_s + "," +
            oldLongitude.to_s + "  count=" + @stateSummaries[ versionedFieldsIn[ KKeyProvinceStateA ]][ "count" ].to_s + "  new lat,long=" + newLatitude.to_s + "," + newLongitude.to_s
    else
      @stateSummaries[ versionedFieldsIn[ KKeyProvinceStateA ]] = { "count" => 1,
                                                            "Confirmed" => rawDataIn[ "Confirmed" ].to_i,
                                                            "Recovered" => rawDataIn[ "Recovered" ].to_i,
                                                            "Deaths" => rawDataIn[ "Deaths" ].to_i,
                                                            "Parent" => versionedFieldsIn[ KKeyCountryRegionA ],
                                                            KKeyLatitudeA => versionedFieldsIn[ KKeyLatitudeA ].to_f,
                                                            KKeyLongitudeA => versionedFieldsIn[ KKeyLongitudeA ].to_f }
    end

    newDaily  = Daily.new( :date => datestringIn, :territory => versionedFieldsIn[ KKeyAdmin2b ], :territoryparent => versionedFieldsIn[ KKeyProvinceStateA ],
                          :summary => false, :confirmed => rawDataIn[ "Confirmed" ], :recovered => rawDataIn[ "Recovered" ],
                          :deaths => rawDataIn[ "Deaths" ], :latitude => versionedFieldsIn[ KKeyLatitudeA ].to_f, :longitude => versionedFieldsIn[ KKeyLongitudeA ].to_f )
    return newDaily
  end


  def indexOnProvinceState( datestringIn, versionedFieldsIn, rawDataIn )
    if @countrySummaries.key?( versionedFieldsIn[ KKeyCountryRegionA ])
      @countrySummaries[ versionedFieldsIn[ KKeyCountryRegionA ]][ "Confirmed" ] += rawDataIn[ "Confirmed" ].to_i
      @countrySummaries[ versionedFieldsIn[ KKeyCountryRegionA ]][ "Recovered" ] += rawDataIn[ "Recovered" ].to_i
      @countrySummaries[ versionedFieldsIn[ KKeyCountryRegionA ]][ "Deaths" ]    += rawDataIn[ "Deaths" ].to_i

      oldLatitude = @countrySummaries[ versionedFieldsIn[ KKeyCountryRegionA ]][ KKeyLatitudeA ]

      latitude      = oldLatitude * @countrySummaries[ versionedFieldsIn[ KKeyCountryRegionA ]][ "count" ] + versionedFieldsIn[ KKeyLatitudeA ].to_f
      newLatitude   = latitude / ( @countrySummaries[ versionedFieldsIn[ KKeyCountryRegionA ]][ "count" ] + 1 )
      @countrySummaries[ versionedFieldsIn[ KKeyCountryRegionA ]][ KKeyLatitudeA ]   = newLatitude
      oldLongitude  = @countrySummaries[ versionedFieldsIn[ KKeyCountryRegionA ]][ KKeyLongitudeA ]
      longitude     = oldLongitude * @countrySummaries[ versionedFieldsIn[ KKeyCountryRegionA ]][ "count" ] + versionedFieldsIn[ KKeyLongitudeA ].to_f
      newLongitude  = longitude / ( @countrySummaries[ versionedFieldsIn[ KKeyCountryRegionA ]][ "count" ] + 1 )
      @countrySummaries[ versionedFieldsIn[ KKeyCountryRegionA ]][ KKeyLongitudeA ]  = newLongitude

      @countrySummaries[ versionedFieldsIn[ KKeyCountryRegionA ]][ "count" ]     += 1
      puts "indexOneFile: country,state=" + versionedFieldsIn[ KKeyCountryRegionA ] + "," + versionedFieldsIn[ KKeyProvinceStateA ] + "  old lat,long=" + oldLatitude.to_s + "," +
            oldLongitude.to_s + "  count=" + @countrySummaries[ versionedFieldsIn[ KKeyCountryRegionA ]][ "count" ].to_s + "  new lat,long=" + newLatitude.to_s + "," + newLongitude.to_s
    else
      @countrySummaries[ versionedFieldsIn[ KKeyCountryRegionA ]] = { "count" => 1,
                                                            "Confirmed" => rawDataIn[ "Confirmed" ].to_i,
                                                            "Recovered" => rawDataIn[ "Recovered" ].to_i,
                                                            "Deaths" => rawDataIn[ "Deaths" ].to_i,
                                                            "Parent" => KTerritoryWorld,
                                                            KKeyLatitudeA => versionedFieldsIn[ KKeyLatitudeA ].to_f,
                                                            KKeyLongitudeA => versionedFieldsIn[ KKeyLongitudeA ].to_f }
    end

    newDaily  = Daily.new( :date => datestringIn, :territory => versionedFieldsIn[ KKeyProvinceStateA ], :territoryparent => versionedFieldsIn[ KKeyCountryRegionA ],
                          :summary => false, :confirmed => rawDataIn[ "Confirmed" ], :recovered => rawDataIn[ "Recovered" ],
                          :deaths => rawDataIn[ "Deaths" ], :latitude => versionedFieldsIn[ KKeyLatitudeA ].to_f, :longitude => versionedFieldsIn[ KKeyLongitudeA ].to_f )
    return newDaily
  end

  def accumulateOnState( datestringIn, stateIn, stateSummaryIn )
    if @countrySummaries.key?( stateSummaryIn[ "Parent" ])
      @countrySummaries[ stateSummaryIn[ "Parent" ]][ "Confirmed" ] += stateSummaryIn[ "Confirmed" ]
      @countrySummaries[ stateSummaryIn[ "Parent" ]][ "Recovered" ] += stateSummaryIn[ "Recovered" ]
      @countrySummaries[ stateSummaryIn[ "Parent" ]][ "Deaths" ]    += stateSummaryIn[ "Deaths" ]

      oldLatitude = @countrySummaries[ stateSummaryIn[ "Parent" ]][ KKeyLatitudeA ]

      latitude      = oldLatitude * @countrySummaries[ stateSummaryIn[ "Parent" ]][ "count" ] + stateSummaryIn[ KKeyLatitudeA ]
      newLatitude   = latitude / ( @countrySummaries[ stateSummaryIn[ "Parent" ]][ "count" ] + 1 )
      @countrySummaries[ stateSummaryIn[ "Parent" ]][ KKeyLatitudeA ]   = newLatitude
      oldLongitude  = @countrySummaries[ stateSummaryIn[ "Parent" ]][ KKeyLongitudeA ]
      longitude     = oldLongitude * @countrySummaries[ stateSummaryIn[ "Parent" ]][ "count" ] + stateSummaryIn[ KKeyLongitudeA ]
      newLongitude  = longitude / ( @countrySummaries[ stateSummaryIn[ "Parent" ]][ "count" ] + 1 )
      @countrySummaries[ stateSummaryIn[ "Parent" ]][ KKeyLongitudeA ]  = newLongitude

      @countrySummaries[ stateSummaryIn[ "Parent" ]][ "count" ]     += 1
      puts "indexOneFile: country,state=" + stateSummaryIn[ "Parent" ] + "," + stateIn + "  old lat,long=" + oldLatitude.to_s + "," +
            oldLongitude.to_s + "  count=" + @countrySummaries[ stateSummaryIn[ "Parent" ]][ "count" ].to_s + "  new lat,long=" + newLatitude.to_s + "," + newLongitude.to_s
    else
      @countrySummaries[ stateSummaryIn[ "Parent" ]] = { "count" => 1,
                                                            "Confirmed" => stateSummaryIn[ "Confirmed" ],
                                                            "Recovered" => stateSummaryIn[ "Recovered" ],
                                                            "Deaths" => stateSummaryIn[ "Deaths" ],
                                                            "Parent" => KTerritoryWorld,
                                                            KKeyLatitudeA => stateSummaryIn[ KKeyLatitudeA ],
                                                            KKeyLongitudeA => stateSummaryIn[ KKeyLongitudeA ]}
    end
  end


  def indexOnCountryRegion( datestringIn, versionedFieldsIn, rawDataIn )
    newDaily  = Daily.new( :date => datestringIn, :territory => versionedFieldsIn[ KKeyCountryRegionA ], :territoryparent => KTerritoryWorld,
                          :summary => false, :confirmed => rawDataIn[ "Confirmed" ], :recovered => rawDataIn[ "Recovered" ],
                          :deaths => rawDataIn[ "Deaths" ], :latitude => versionedFieldsIn[ KKeyLatitudeA ].to_f, :longitude => versionedFieldsIn[ KKeyLongitudeA ].to_f )

    @worldTotals[ "Confirmed" ] += rawDataIn[ "Confirmed" ].to_i
    @worldTotals[ "Recovered" ] += rawDataIn[ "Recovered" ].to_i
    @worldTotals[ "Deaths" ]    += rawDataIn[ "Deaths" ].to_i

    return newDaily
  end
end
