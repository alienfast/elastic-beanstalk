module Elastic
  module Beanstalk

    module Spinner
      # it's a singleton, thus implemented as a self-extended module
      extend self

      def show(fps=10)
        chars = %w{ | / - \\ }
        delay = 1.0/fps
        iter = 0
        spinner = Thread.new do
          while iter do # Keep spinning until told otherwise

            print chars[0]
            sleep delay
            print "\b"
            chars.push chars.shift
          end
        end
        yield.tap {# After yielding to the block, save the return value
          iter = false # Tell the thread to exit, cleaning up after itself…
          spinner.join # …and wait for it to do so.
        } # Use the block's return value as the method's
      end
    end
  end
end

