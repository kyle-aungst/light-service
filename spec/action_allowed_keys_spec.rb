require 'spec_helper'
require 'test_doubles'

describe ":allows macro" do
  context "when the allowed key is not set by the action" do
    it "does not raise an error" do
      expect do
        TestDoubles::MakesLatteMaybeSweetAction
          .execute(:coffee => "espresso", :milk => "2%")
      end.not_to raise_error
    end

    it "does not add the key to the context" do
      result = TestDoubles::MakesLatteMaybeSweetAction
               .execute(:coffee => "espresso", :milk => "2%")

      expect(result).to be_success
      expect(result.keys).not_to include(:sugar)
    end
  end

  context "when the allowed key is set by the action" do
    it "adds the key to the context" do
      result = TestDoubles::MakesLatteMaybeSweetAction
               .execute(:coffee => "espresso", :milk => "oat")

      expect(result[:sugar]).to eq("brown sugar")
    end

    it "adds the key to the context when it is set to nil" do
      module TestDoubles
        class SetsSugarToNilAction
          extend LightService::Action
          allows :sugar

          executed do |context|
            context.sugar = nil
          end
        end
      end

      result = TestDoubles::SetsSugarToNilAction.execute

      expect(result.keys).to include(:sugar)
      expect(result[:sugar]).to be_nil
    end
  end

  context "when the allowed key is read but not in the context" do
    it "returns nil without adding the key to the context" do
      result = TestDoubles::ReadsSugarAction.execute(:latte => "latte")

      expect(result.latte).to eq("latte")
      expect(result.keys).not_to include(:sugar)
    end
  end

  context "when an earlier action expected the key" do
    it "reads it without adding it back to the context" do
      module TestDoubles
        class ExpectsAndRemovesSugarAction
          extend LightService::Action
          expects :sugar

          executed do |context|
            context.delete(:sugar) if context.sugar == "none"
          end
        end
      end

      context = LightService::Context.make(:latte => "latte", :sugar => "none")
      TestDoubles::ExpectsAndRemovesSugarAction.execute(context)
      result = TestDoubles::ReadsSugarAction.execute(context)

      expect(result.latte).to eq("latte")
      expect(result.keys).not_to include(:sugar)
    end
  end

  context "when the allowed key is already in the context" do
    it "can be read by the action" do
      result = TestDoubles::ReadsSugarAction
               .execute(:latte => "latte", :sugar => "honey")

      expect(result.latte).to eq("latte and honey")
      expect(result[:sugar]).to eq("honey")
    end
  end

  context "when used in an organizer" do
    it "passes the key to later actions when it was set" do
      result = TestDoubles::MakesLatteMaybeSweetOrganizer.call("oat")

      expect(result.latte).to eq("espresso - with oat milk and brown sugar")
    end

    it "leaves the key out of the context when it was not set" do
      result = TestDoubles::MakesLatteMaybeSweetOrganizer.call("2%")

      expect(result).to be_success
      expect(result.latte).to eq("espresso - with 2% milk")
      expect(result.keys).not_to include(:sugar)
    end
  end

  context "when the allowed key is also expected" do
    it "still raises an error if the key is not in the context" do
      module TestDoubles
        class ExpectsAndAllowsSugarAction
          extend LightService::Action
          expects :sugar
          allows :sugar

          executed { |_context| nil }
        end
      end

      expect do
        TestDoubles::ExpectsAndAllowsSugarAction.execute
      end.to raise_error(LightService::ExpectedKeysNotInContextError)
    end
  end

  context "when a reserved key is listed as an allowed key" do
    it "raises an error indicating a reserved key is allowed" do
      module TestDoubles
        class AllowsReservedKeyAction
          extend LightService::Action
          allows :message

          executed { |_context| nil }
        end
      end

      exception_msg = "promised, expected or allowed keys cannot be a " \
                      "reserved key: [:message]"
      expect do
        TestDoubles::AllowsReservedKeyAction.execute
      end.to \
        raise_error(LightService::ReservedKeysInContextError, exception_msg)
    end
  end

  context "when the `allows` macro is called multiple times" do
    it "collects allowed keys" do
      module TestDoubles
        class MultipleAllowsAction
          extend LightService::Action
          allows :sugar
          allows :cinnamon

          executed { |_context| nil }
        end
      end

      expect(TestDoubles::MultipleAllowsAction.allowed_keys)
        .to eq(%i[sugar cinnamon])
    end
  end
end
