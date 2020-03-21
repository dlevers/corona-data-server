class WelcomeController < ApplicationController
  def index
    dataPathBase  = "/Users/dlevers/Src/Sandbox/Coronavirus19/data/JohnsHopkinsPipedream/"
    # fileName      = "2020-03-20-13.22.json"
    allSummary  = { "Confirmed" => 0 }

    Dir.foreach( dataPathBase ) do |filename|
      next if filename == '.' or filename == '..'
      # Do work on the remaining files & directories
      allSummary[ "Confirmed" ] += indexOneFile( dataPathBase, filename )
    end
    puts "---"
    puts "allSummary.Confirmed=" + allSummary[ "Confirmed" ].to_s
  end

  private
  def indexOneFile( pathIn, filenameIn )
    fjs = File.read( pathIn + filenameIn )
    ojs = JSON.parse( fjs )

    totalConfirmed  = 0

    puts "pathIn:        " + pathIn
    puts "filenameIn:    " + filenameIn
    puts "apiSourceCode: " + ojs[ "apiSourceCode" ]

    puts "---"
    puts "entry count=" + ojs[ "rawData" ].length.to_s
    countrySummaries  = {}

    puts "---"
    puts "standalone countries"
    ojs[ "rawData" ].each do |oneRawValue|
      if oneRawValue[ "Province/State" ].length > 0
        if countrySummaries.key?( oneRawValue[ "Country/Region" ])
          countrySummaries[ oneRawValue[ "Country/Region" ]][ "Confirmed" ] += oneRawValue[ "Confirmed" ].to_i
        else
          countrySummaries[ oneRawValue[ "Country/Region" ]] = { "Confirmed" => oneRawValue[ "Confirmed" ].to_i }
        end

        # puts "running one.Country/Region=" + oneRawValue[ "Country/Region" ] + " add=" + oneRawValue[ "Confirmed" ].to_s + "  confirmed=" + countrySummaries[ oneRawValue[ "Country/Region" ]][ "Confirmed" ].to_s
      else
        puts "one.Country/Region=" + oneRawValue[ "Country/Region" ] + "  confirmed=" + oneRawValue[ "Confirmed" ]
        totalConfirmed  += oneRawValue[ "Confirmed" ].to_i
      end
    end

    # Now for all those that saw accumulated province/state(s)
    puts "---"
    puts "countries with provinces/states"
    countrySummaries.each do |oneKey, oneValue|
      puts "one.accumulated.Country/Region=" + oneKey + " total confirmed=" + countrySummaries[ oneKey ][ "Confirmed" ].to_s
      totalConfirmed += countrySummaries[ oneKey ][ "Confirmed" ]
    end

    return totalConfirmed
  end
end
