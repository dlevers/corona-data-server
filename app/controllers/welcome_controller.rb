class WelcomeController < ApplicationController
  def index
    dataPathBase  = "/Users/dlevers/Src/Sandbox/Coronavirus19/data/JohnsHopkinsPipedream/"
    fileName      = "2020-03-20-13.22.json"
    fjs = File.read( dataPathBase + fileName )
    ojs = JSON.parse( fjs )

    puts "apiSourceCode: " + ojs[ "apiSourceCode" ]

    puts "entry count=" + ojs[ "rawData" ].length.to_s
    countrySummaries  = {}
    ojs[ "rawData" ].each do |oneRawValue|
      if oneRawValue[ "Province/State" ].length > 0
        if countrySummaries.key?( oneRawValue[ "Country/Region" ])
          countrySummaries[ oneRawValue[ "Country/Region" ]][ "Confirmed" ] += oneRawValue[ "Confirmed" ].to_i
        else
          countrySummaries[ oneRawValue[ "Country/Region" ]] = { "Confirmed" => oneRawValue[ "Confirmed" ].to_i }
        end

        puts "running one.Country/Region=" + oneRawValue[ "Country/Region" ] + " add=" + oneRawValue[ "Confirmed" ].to_s + "  confirmed=" + countrySummaries[ oneRawValue[ "Country/Region" ]][ "Confirmed" ].to_s
      else
        puts "one.Country/Region=" + oneRawValue[ "Country/Region" ] + "  confirmed=" + oneRawValue[ "Confirmed" ]
      end
    end
  end
end
