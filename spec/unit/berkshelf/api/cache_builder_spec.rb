require 'spec_helper'

describe Berkshelf::API::CacheBuilder do

  before { Berkshelf::API::CacheManager.start }
  let(:instance) { described_class.new }

  describe "#build" do
    subject(:build) { instance.build }
    let(:workers) { [ double('worker') ] }
    let(:future) { double('future', value: nil) }
    let(:cache_manager) { double('cache_manager') }

    before { instance.stub(workers: workers) }

    it "asks the cache_manager to process all of its actors" do
      instance.stub(:cache_manager).and_return(cache_manager)
      cache_manager.should_receive(:process_workers).with(instance.workers).and_return(future)
      build
    end
  end

  describe "#workers" do
    subject(:workers) { instance.workers }

    it "returns an array of workers" do
      expect(workers).to be_a(Array)
      workers.each do |worker|
        expect(worker).to be_a(described_class::Worker::Base)
      end
    end

    context "when no workers are explicitly configured" do
      it "has one worker started by default" do
        expect(workers).to have(1).item
      end

      it "has an opscode worker started by default" do
        expect(workers.first).to be_a(described_class::Worker::Opscode)
      end
    end

    context "when there are multiple workers" do
      let(:endpoint_array) { [ first_worker, second_worker ] }
      let(:first_worker) { double(options: endpoint_options.dup.merge(priority: 0), type: 'chicken') }
      let(:second_worker) { double(options: endpoint_options.dup.merge(priority: 1), type: 'tuna') }
      let(:endpoint_options) do
        {
          "url" => "www.fake.com",
          "client_name" => "fake",
          "client_key" => "/path/to/fake.key"
        }
      end
      let(:dummy_endpoint_klass) do
        Class.new do
          attr_reader :options
          include Celluloid

          def initialize(options = {})
            @options = options
          end
        end
      end

      before do
        Berkshelf::API::Application.config.stub(:endpoints).and_return(endpoint_array)
        Berkshelf::API::CacheBuilder::Worker.stub(:[]).and_return(dummy_endpoint_klass, dummy_endpoint_klass)
      end

      it "has two workers" do
        expect(workers).to have(2).items
      end

      it "keeps the ordering" do
        expect(workers.first.options[:priority]).to be(0)
        expect(workers.last.options[:priority]).to be(1)
      end
    end
  end
end
