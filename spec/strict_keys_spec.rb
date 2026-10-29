require 'spec_helper'
require 'test_doubles'

describe "Strict keys" do
  module TestDoubles
    class ReadsMilkAction
      extend LightService::Action
      expects :coffee

      executed do |context|
        context[:latte] = "#{context.coffee} with #{context[:milk]}"
      end
    end

    class StrictLatteAction
      extend LightService::Action
      expects :coffee
      allows :milk
      promises :latte

      executed do |context|
        context.latte = [context.coffee, context.milk].compact.join(" with ")
      end
    end

    class StrictLatteOrganizer
      extend LightService::Organizer

      def self.call(context)
        with(context).reduce(
          reduce_if(->(ctx) { ctx[:size] == :large },
                    [StrictLatteAction]),
          add_to_context(:served => true)
        )
      end
    end

    class RunsStrictLatteAction
      extend LightService::Action
      expects :coffee

      executed do |context|
        TestDoubles::StrictLatteAction.execute(context)
      end
    end

    class RunsReadsMilkAction
      extend LightService::Action
      expects :coffee

      executed do |context|
        TestDoubles::StrictLatteAction.execute(context)
        context[:milk]
      end
    end
  end

  around do |example|
    LightService::Configuration.strict_keys = strict_keys
    example.run
  ensure
    LightService::Configuration.strict_keys = nil
  end

  context "when strict keys are off" do
    let(:strict_keys) { nil }

    it "lets an action read keys it doesn't declare" do
      result = TestDoubles::ReadsMilkAction
               .execute(:coffee => "espresso", :milk => "oat")

      expect(result[:latte]).to eq("espresso with oat")
    end
  end

  context "when strict keys are on" do
    let(:strict_keys) { true }

    it "raises when an action reads a key it doesn't declare" do
      exception_msg = "TestDoubles::ReadsMilkAction used :milk without " \
                      "declaring it with expects, promises or allows"

      expect do
        TestDoubles::ReadsMilkAction
          .execute(:coffee => "espresso", :milk => "oat")
      end.to raise_error(LightService::UndeclaredKeyError, exception_msg)
    end

    it "raises when an action writes a key it doesn't declare" do
      expect do
        TestDoubles::AddsTwoActionWithFetch.execute
      end.to raise_error(LightService::UndeclaredKeyError, /:number/)
    end

    it "checks other ways of reading a key" do
      context = LightService::Context.make(:coffee => "espresso")
      reads = [
        ->(ctx) { ctx.fetch(:milk, nil) },
        ->(ctx) { ctx.key?(:milk) },
        ->(ctx) { ctx.dig(:milk, :type) },
        ->(ctx) { ctx.values_at(:coffee, :milk) },
        ->(ctx) { ctx.merge!(:milk => "oat") }
      ]

      reads.each do |read|
        action = Class.new do
          extend LightService::Action
          expects :coffee

          executed { |ctx| read.call(ctx) }
        end

        expect { action.execute(context) }
          .to raise_error(LightService::UndeclaredKeyError)
      end
    end

    it "raises for a reader an earlier action defined" do
      context = LightService::Context.make(:coffee => "espresso",
                                           :milk => "oat")
      TestDoubles::StrictLatteAction.execute(context)

      action = Class.new do
        extend LightService::Action
        expects :coffee

        executed(&:milk)
      end

      expect { action.execute(context) }
        .to raise_error(LightService::UndeclaredKeyError, /:milk/)
    end

    it "doesn't check organizer steps or code outside actions" do
      result = TestDoubles::StrictLatteOrganizer
               .call(:coffee => "espresso", :size => :large)

      expect(result.latte).to eq("espresso")
      expect(result[:served]).to be(true)
      expect(result[:size]).to eq(:large)
    end

    it "doesn't check callback steps against the callback action's keys" do
      result = TestDoubles::TestWithCallback.call

      expect(result).to be_success
    end

    it "doesn't check hooks of an action run from another action" do
      context = LightService::Context.make(
        :coffee => "espresso",
        :size => :large,
        :_before_actions => [->(ctx) { ctx[:size] }]
      )

      result = TestDoubles::RunsStrictLatteAction.execute(context)

      expect(result.latte).to eq("espresso")
    end

    it "doesn't check aliases or defaults for an action run from another" do
      inner_organizer = Class.new do
        extend LightService::Organizer
        aliases :coffee => :espresso

        def self.call(context)
          with(context).reduce(
            Class.new do
              extend LightService::Action
              expects :espresso
              expects :sugar, :default => "none"

              executed(&:espresso)
            end
          )
        end
      end
      outer_action = Class.new do
        extend LightService::Action
        expects :coffee

        executed { |ctx| inner_organizer.call(ctx) }
      end

      expect { outer_action.execute(:coffee => "espresso") }
        .not_to raise_error
    end

    it "checks an action run from another action against its own keys" do
      expect do
        TestDoubles::RunsReadsMilkAction
          .execute(:coffee => "espresso", :milk => "oat")
      end.to raise_error(LightService::UndeclaredKeyError,
                         /RunsReadsMilkAction used :milk/)
    end
  end
end
