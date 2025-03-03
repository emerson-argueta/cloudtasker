# frozen_string_literal: true

require 'cloudtasker/backend/redis_task'

RSpec.describe Cloudtasker::CloudTask do
  let(:gct_klass) do
    if !defined?(Google::Cloud::Tasks::VERSION) || Google::Cloud::Tasks::VERSION < '2'
      require 'cloudtasker/backend/google_cloud_task_v1'
      Cloudtasker::Backend::GoogleCloudTaskV1
    else
      require 'cloudtasker/backend/google_cloud_task_v2'
      Cloudtasker::Backend::GoogleCloudTaskV2
    end
  end
  let(:task_class) do
    if !defined?(Google::Cloud::Tasks::VERSION) || Google::Cloud::Tasks::VERSION < '2'
      'Google::Cloud::Tasks::V2beta3::Task'
    else
      'Google::Cloud::Tasks::V2::Task'
    end
  end

  let(:backend) { class_double(gct_klass) }
  let(:payload) do
    {
      id: '123',
      http_request: { foo: 'bar' },
      schedule_time: 2,
      retries: 3,
      queue: 'critical',
      dispatch_deadline: 500
    }
  end
  let(:resp) { instance_double(task_class, to_h: payload) }

  describe '.backend' do
    subject { described_class.backend }

    before { described_class.instance_variable_set('@backend', nil) }
    before { allow(Cloudtasker.config).to receive(:mode).and_return(environment) }

    context 'with development mode' do
      let(:environment) { 'development' }

      it { is_expected.to eq(Cloudtasker::Backend::RedisTask) }
    end

    context 'with production mode' do
      let(:environment) { 'production' }

      it { is_expected.to eq(gct_klass) }
    end
  end

  describe '.gct_backend' do
    subject { described_class.gct_backend }

    it { is_expected.to eq(gct_klass) }
  end

  describe '.setup_production_queue' do
    subject { described_class.setup_production_queue(**args) }

    let(:args) { { name: 'critical', concurrency: 20, retries: 100 } }
    let(:queue) { instance_double('Google::Cloud::Tasks::V2::Queue') }

    before { expect(gct_klass).to receive(:setup_queue).with(**args).and_return(queue) }
    it { is_expected.to eq(queue) }
  end

  describe '.find' do
    subject { described_class.find(id) }

    let(:id) { '123' }
    let(:call_resp) { resp }

    before { allow(described_class).to receive(:backend).and_return(backend) }
    before { allow(backend).to receive(:find).with(id).and_return(call_resp) }

    context 'with response' do
      it { is_expected.to eq(described_class.new(**payload)) }
    end

    context 'with no response' do
      let(:call_resp) { nil }

      it { is_expected.to be_nil }
    end
  end

  describe '.create' do
    subject(:create_task) { described_class.create(payload) }

    let(:call_resp) { resp }

    before { allow(described_class).to receive(:backend).and_return(backend) }
    before { allow(backend).to receive(:create).with(payload).and_return(call_resp) }

    context 'with response' do
      it { is_expected.to eq(described_class.new(**payload)) }
    end

    context 'with no response' do
      let(:call_resp) { nil }

      it { is_expected.to be_nil }
    end

    context 'with max task size exceeded' do
      let(:payload) { 'a' * 1024 * 101 }

      it { expect { create_task }.to raise_error(Cloudtasker::MaxTaskSizeExceededError) }
    end
  end

  describe '.delete' do
    subject { described_class.delete(id) }

    let(:id) { '123' }

    before { allow(described_class).to receive(:backend).and_return(backend) }
    before { allow(backend).to receive(:delete).with(id).and_return(resp) }

    it { is_expected.to eq(resp) }
  end

  describe '.new' do
    subject { described_class.new(**payload) }

    it { is_expected.to have_attributes(payload) }
  end

  describe '#==' do
    subject { described_class.new(**payload) }

    context 'with same id' do
      it { is_expected.to eq(described_class.new(**payload)) }
    end

    context 'with different id' do
      it { is_expected.not_to eq(described_class.new(**payload.merge(id: payload[:id] + 'a'))) }
    end

    context 'with different object' do
      it { is_expected.not_to eq('foo') }
    end
  end
end
