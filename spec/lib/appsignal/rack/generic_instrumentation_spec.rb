describe Appsignal::Rack::GenericInstrumentation do
  before :all do
    start_agent
  end

  let(:app) { double(:call => true) }
  let(:env) { { :path => "/", :method => "GET" } }
  let(:options) { {} }
  let(:middleware) { Appsignal::Rack::GenericInstrumentation.new(app, options) }

  describe "#call" do
    before do
      allow(middleware).to receive(:raw_payload).and_return({})
    end

    context "when appsignal is active" do
      before { allow(Appsignal).to receive(:active?).and_return(true) }

      it "should call with monitoring" do
        expect(middleware).to receive(:call_with_appsignal_monitoring).with(env)
      end
    end

    context "when appsignal is not active" do
      before { allow(Appsignal).to receive(:active?).and_return(false) }

      it "should not call with monitoring" do
        expect(middleware).to_not receive(:call_with_appsignal_monitoring)
      end

      it "should call the stack" do
        expect(app).to receive(:call).with(env)
      end
    end

    after { middleware.call(env) }
  end

  describe "#call_with_appsignal_monitoring" do
    it "should create a transaction" do
      expect(Appsignal::Transaction).to receive(:create).with(
        kind_of(String),
        Appsignal::Transaction::HTTP_REQUEST,
        kind_of(Rack::Request)
      ).and_return(double(:set_action => nil, :set_http_or_background_queue_start => nil, :set_metadata => nil))
    end

    it "should call the app" do
      expect(app).to receive(:call).with(env)
    end

    context "with an error" do
      let(:error) { VerySpecificError.new }
      let(:app) do
        double.tap do |d|
          allow(d).to receive(:call).and_raise(error)
        end
      end

      it "should set the error" do
        expect_any_instance_of(Appsignal::Transaction).to receive(:set_error).with(error)
      end
    end

    it "should set the action to unknown" do
      expect_any_instance_of(Appsignal::Transaction).to receive(:set_action).with("unknown")
    end

    context "with a route specified in the env" do
      before do
        env["appsignal.route"] = "GET /"
      end

      it "should set the action" do
        expect_any_instance_of(Appsignal::Transaction).to receive(:set_action).with("GET /")
      end
    end

    it "should set metadata" do
      expect_any_instance_of(Appsignal::Transaction).to receive(:set_metadata).twice
    end

    it "should set the queue start" do
      expect_any_instance_of(Appsignal::Transaction).to receive(:set_http_or_background_queue_start)
    end

    after { middleware.call(env) rescue VerySpecificError }
  end
end
