module Elastic
  module Beanstalk

    module SmokeTester
      # it's a singleton, thus implemented as a self-extended module
      extend self

      def test_url(url, timeout, sleep_wait, expected_text)

        puts '-------------------------------------------------------------------------------'
#    puts "Smoke Testing: \n\turl: #{url}\n\ttimeout: #{timeout}\n\tsleep_wait: #{sleep_wait}\n\texpected_text: #{expected_text}\n"
        puts "Smoke Testing: \n\turl: #{url}\n\ttimeout: #{timeout}\n\texpected_text: #{expected_text}\n"
        response = nil
        begin
          Timeout.timeout(timeout) do
            i = 0
            begin
              sleep sleep_wait.to_i unless (i == 0)
              i += 1
              begin
                response = Net::HTTP.get_response(URI(url))
              rescue SocketError => e
                response = ResponseStub.new({code: e.message, body: ''})
              end

              puts "\t\t[#{response.code}]"
              #puts "\t#{response.body}"
            end until (!response.nil? && response.code.to_i == 200 && response.body.include?(expected_text))
          end
        ensure
          puts "\nFinal response: \n\tcode: [#{response.code}] \n\texpectation met: #{response.body.include?(expected_text)}"
          puts '-------------------------------------------------------------------------------'
        end
      end

      private

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