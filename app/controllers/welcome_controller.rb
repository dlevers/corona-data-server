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
    dataPathBase        = "/Users/dlevers/Src/Sandbox/Coronavirus19/data/JohnsHopkinsPipedream/"
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
    fjs = File.read( pathIn + filenameIn )
    ojs = JSON.parse( fjs )

    totals  = { "Confirmed" => 0,
                "Recovered" => 0,
                "Deaths" => 0 }

    puts "indexOneFile: pathIn:        " + pathIn
    puts "indexOneFile: filenameIn:    " + filenameIn
    @stateSummaries   = {}
    @countrySummaries = {}

    # puts "indexOneFile: standalone countries"
    ojs[ "rawData" ].each do |oneRawValue|
      # puts "indexOneFile: oneRawValue - " + oneRawValue.to_s
      #if oneRawValue[ "Province/State" ].length > 0
      versionedFields = { KKeyCountryRegionA => "",
                        KKeyProvinceStateA => "",
                        KKeyAdmin2b => "",
                        KKeyLatitudeA => 0.0,
                        KKeyLongitudeA => 0.0 }

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

      @daily  = nil
      if versionedFields[ KKeyAdmin2b ].length > 0
        @daily  = indexOnAdmin2( datestringIn, versionedFields, oneRawValue )
      elsif versionedFields[ KKeyProvinceStateA ].length > 0
        @daily  = indexOnProvinceState( datestringIn, versionedFields, oneRawValue )
      else
        @daily  = indexOnCountryRegion( datestringIn, versionedFields, oneRawValue )
      end

      @daily.save
    end

    # Summarize accumulated states
    puts "indexOneFile: states with counties"
    @stateSummaries.each do |oneKey, oneValue|
      puts "indexOneFile: one.accumulated.state=" + oneKey + " total confirmed=" + @stateSummaries[ oneKey ][ "Confirmed" ].to_s

      @daily  = Daily.new( :date => datestringIn, :territory => oneKey, :territoryparent => oneValue[ "Parent" ], :summary => true, :confirmed => oneValue[ "Confirmed" ].to_s,
                          :recovered => oneValue[ "Recovered" ].to_s, :deaths => oneValue[ "Deaths" ].to_s, :latitude => oneValue[ "Latitude" ],
                          :longitude => oneValue[ "Longitude" ] )
      @daily.save

      # # totalConfirmed += countrySummaries[ oneKey ][ "Confirmed" ]
      # @countrySummaries[ "Confirmed" ] += countrySummaries[ oneKey ][ "Confirmed" ]
      # totals[ "Recovered" ] += countrySummaries[ oneKey ][ "Recovered" ]
      # totals[ "Deaths" ]    += countrySummaries[ oneKey ][ "Deaths" ]
      accumulateOnState( datestringIn, oneKey, oneValue )
    end

    # Summarize accumulated countries
    puts "indexOneFile: countries with provinces/states"
    @countrySummaries.each do |oneKey, oneValue|
      puts "indexOneFile: datestringIn=" + datestringIn + "  one.accumulated.Country/Region=" + oneKey + " total confirmed=" + @countrySummaries[ oneKey ][ "Confirmed" ].to_s

      @daily  = Daily.new( :date => datestringIn, :territory => oneKey, :territoryparent => KTerritoryWorld, :summary => true, :confirmed => oneValue[ "Confirmed" ].to_s,
                          :recovered => oneValue[ "Recovered" ].to_s, :deaths => oneValue[ "Deaths" ].to_s, :latitude => oneValue[ "Latitude" ],
                          :longitude => oneValue[ "Longitude" ] )
      @daily.save

      # totalConfirmed += countrySummaries[ oneKey ][ "Confirmed" ]
      totals[ "Confirmed" ] += @countrySummaries[ oneKey ][ "Confirmed" ]
      totals[ "Recovered" ] += @countrySummaries[ oneKey ][ "Recovered" ]
      totals[ "Deaths" ]    += @countrySummaries[ oneKey ][ "Deaths" ]
    end

    # Summarize the world
    @daily  = Daily.new( :date => datestringIn, :territory => KTerritoryWorld, :territoryparent => "(none)", :summary => true, :confirmed => totals[ "Confirmed" ].to_s,
                        :recovered => totals[ "Recovered" ].to_s, :deaths => totals[ "Deaths" ].to_s, :latitude => 0.0, :longitude => 0.0 )
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

    # newDaily  = Daily.new( :date => datestringIn, :territory => versionedFieldsIn[ KKeyProvinceStateA ], :territoryparent => versionedFieldsIn[ KKeyCountryRegionA ],
    #                       :summary => false, :confirmed => rawDataIn[ "Confirmed" ], :recovered => rawDataIn[ "Recovered" ],
    #                       :deaths => rawDataIn[ "Deaths" ], :latitude => versionedFieldsIn[ KKeyLatitudeA ].to_f, :longitude => versionedFieldsIn[ KKeyLongitudeA ].to_f )
    # return newDaily
  end


  def indexOnCountryRegion( datestringIn, versionedFieldsIn, rawDataIn )
    newDaily  = Daily.new( :date => datestringIn, :territory => versionedFieldsIn[ KKeyCountryRegionA ], :territoryparent => KTerritoryWorld,
                          :summary => false, :confirmed => rawDataIn[ "Confirmed" ], :recovered => rawDataIn[ "Recovered" ],
                          :deaths => rawDataIn[ "Deaths" ], :latitude => versionedFieldsIn[ KKeyLatitudeA ].to_f, :longitude => versionedFieldsIn[ KKeyLongitudeA ].to_f )

    # @totals[ "Confirmed" ] += rawDataIn[ "Confirmed" ].to_i
    # @totals[ "Recovered" ] += rawDataIn[ "Recovered" ].to_i
    # @totals[ "Deaths" ]    += rawDataIn[ "Deaths" ].to_i
    if @countrySummaries.key?( versionedFieldsIn[ KKeyCountryRegionA ])
      puts "indexOnCountryRegion: UNEXPECTED KKeyCountryRegion=" + versionedFieldsIn[ KKeyCountryRegionA ]
    end

    @countrySummaries[ versionedFieldsIn[ KKeyCountryRegionA ]] = { "count" => 1,
                                      "Confirmed" => rawDataIn[ "Confirmed" ].to_i,
                                      "Recovered" => rawDataIn[ "Recovered" ].to_i,
                                      "Deaths" => rawDataIn[ "Deaths" ].to_i,
                                      "Parent" => KTerritoryWorld,
                                      KKeyLatitudeA => versionedFieldsIn[ KKeyLatitudeA ].to_f,
                                      KKeyLongitudeA => versionedFieldsIn[ KKeyLongitudeA ].to_f }

    return newDaily
  end


  #   # Now for all those that saw accumulated province/state(s)
  #   puts "---"
  #   puts "indexOneFile: countries with provinces/states"
  #   stateSummaries.each do |oneKey, oneValue|
  #     puts "indexOneFile: one.accumulated.Country-Region=" + oneKey + " total confirmed=" + stateSummaries[ oneKey ][ "Confirmed" ].to_s

  #     @daily  = Daily.new( :date => datestringIn, :territory => oneKey, :territoryparent => KTerritoryWorld, :summary => true, :confirmed => oneValue[ "Confirmed" ].to_s,
  #                         :recovered => oneValue[ "Recovered" ].to_s, :deaths => oneValue[ "Deaths" ].to_s, :latitude => oneValue[ KKeyLatitudeA ],
  #                         :longitude => oneValue[ KKeyLongitudeA ] )
  #     @daily.save

  #     # totalConfirmed += stateSummaries[ oneKey ][ "Confirmed" ]
  #     totals[ "Confirmed" ] += stateSummaries[ oneKey ][ "Confirmed" ]
  #     totals[ "Recovered" ] += stateSummaries[ oneKey ][ "Recovered" ]
  #     totals[ "Deaths" ]    += stateSummaries[ oneKey ][ "Deaths" ]
  #   end

  #   puts "indexOneFile: totals.Confirmed,Recovered,Deaths=" + totals[ "Confirmed" ].to_s + "," + totals[ "Recovered" ].to_s + "," + totals[ "Deaths" ].to_s
  #   @daily  = Daily.new( :date => datestringIn, :territory => KTerritoryWorld, :territoryparent => "(none)", :summary => true, :confirmed => totals[ "Confirmed" ].to_s,
  #                       :recovered => totals[ "Recovered" ].to_s, :deaths => totals[ "Deaths" ].to_s, :latitude => 0.0, :longitude => 0.0 )
  #   @daily.save

  #   return totals[ "Confirmed" ]
  # end
end
