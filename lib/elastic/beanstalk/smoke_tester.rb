require 'timeout'
require 'net/http'
require 'elastic/beanstalk/spinner'
require 'nokogiri'

module Elastic
  module Beanstalk

    module SmokeTester
      # it's a singleton, thus implemented as a self-extended module
      extend self

      def test_url(url, timeout, sleep_wait, expected_text)

        puts '-------------------------------------------------------------------------------'
#    puts "Smoke Testing: \n\turl: #{url}\n\ttimeout: #{timeout}\n\tsleep_wait: #{sleep_wait}\n\texpected_text: #{expected_text}\n"
        puts "Smoke Test: \n\turl: #{url}\n\ttimeout: #{timeout}\n\texpected_text: #{expected_text}"
        response = nil
        begin
          Timeout.timeout(timeout) do
            i = 0
            print "\nRunning..."
            Spinner.show {
              begin
                sleep sleep_wait.to_i unless (i == 0)
                i += 1
                begin
                  response = Net::HTTP.get_response(URI(url))
                    #rescue SocketError => e
                    #  response = ResponseStub.new({code: e.message, body: ''})
                rescue => e
                  response = ResponseStub.new({code: e.message, body: ''})
                end

                puts "\t\t[#{response.code}]"
                #puts "\t#{response.body}"

                #
                # Let's try to get out quickly when the deploy has gone wrong.
                #
                break if received_fatal_error?(response)

              end until (!response.nil? && response.code.to_i == 200 && response.body.include?(expected_text))
            }
          end
        ensure
          puts "\n\nFinal response code: [#{response.code}] expectation met: #{response.body.include?(expected_text)}"
          puts '-------------------------------------------------------------------------------'
        end
      end

      private

      def received_fatal_error?(response)
        fatal_error = false
        #['Bundler::PathError'].each do |code|
          # fail right away on known terminal cases.
          #if (!response.nil? && response.code.to_i == 500 && response.body.include?(code))
        if (!response.nil? && response.code.to_i == 500 && response.body.include?('rror'))

            doc = Nokogiri::HTML(response.body)

            # By default, let's grab the info from the Passenger error page...
            $stderr.puts "\t\t[#{response.code}] #{code}"
            $stderr.puts "\t\t\t#{get_content(doc, '//h1')}"
            $stderr.puts "\t\t\t#{get_content(doc, '//dl/dd')}"
            fatal_error = true
#            break
          end
        #end

        fatal_error
      end

      def get_content(doc, xpath)
        value = ''
        begin
          element = doc.xpath(xpath)
          element = element.first unless element.nil?
          value = element.content unless element.nil?
        rescue
        end
        value
      end

      class ResponseStub

        attr_reader :code, :body

        def initialize(args)
          @code = args[:code]
          @body = args[:body]
        end
      end
    end
  end
end