# frozen_string_literal: true

RSpec.describe Cloudtasker::WorkerController, type: :controller do
  routes { Cloudtasker::Engine.routes }

  describe 'POST #run' do
    subject { post :run, body: payload.to_json, as: :json }

    let(:payload) do
      {
        worker: worker_class_name,
        job_id: id,
        job_args: args,
        job_meta: meta,
        job_queue: queue,
        other: :foo
      }
    end
    let(:expected_payload) do
      payload.slice(:worker, :job_id, :job_args, :job_meta, :job_queue)
             .merge(job_retries: retries)
    end
    let(:id) { '111' }
    let(:worker_class_name) { 'TestWorker' }
    let(:args) { [1, 2] }
    let(:meta) { { 'foo' => 'bar' } }
    let(:retries) { 3 }
    let(:queue) { 'some-queue' }
    let(:auth_token) { Cloudtasker::Authenticator.verification_token }

    before { request.env['HTTP_X_CLOUDTASKS_TASKEXECUTIONCOUNT'] = retries }

    context 'with valid worker' do
      before do
        request.env['HTTP_AUTHORIZATION'] = "Bearer #{auth_token}"
        allow(Cloudtasker::WorkerHandler).to receive(:execute_from_payload!)
          .with(expected_payload)
          .and_return(true)
      end
      after { expect(Cloudtasker::WorkerHandler).to have_received(:execute_from_payload!) }
      it { is_expected.to be_successful }
    end

    context 'with execution errors' do
      before do
        request.env['HTTP_AUTHORIZATION'] = "Bearer #{auth_token}"
        allow(Cloudtasker::WorkerHandler).to receive(:execute_from_payload!)
          .with(expected_payload)
          .and_raise(ArgumentError)
      end
      it { is_expected.to have_http_status(:unprocessable_entity) }
    end

    context 'with dead worker' do
      before do
        request.env['HTTP_AUTHORIZATION'] = "Bearer #{auth_token}"
        allow(Cloudtasker::WorkerHandler).to receive(:execute_from_payload!)
          .with(expected_payload)
          .and_raise(Cloudtasker::DeadWorkerError)
      end
      it { is_expected.to have_http_status(:reset_content) }
    end

    context 'with invalid worker' do
      before do
        request.env['HTTP_AUTHORIZATION'] = "Bearer #{auth_token}"
        allow(Cloudtasker::WorkerHandler).to receive(:execute_from_payload!)
          .with(expected_payload)
          .and_raise(Cloudtasker::InvalidWorkerError)
      end
      it { is_expected.to have_http_status(:not_found) }
    end

    context 'with no authentication' do
      it { is_expected.to have_http_status(:unauthorized) }
    end

    context 'with invalid authentication' do
      before { request.env['HTTP_AUTHORIZATION'] = "Bearer #{auth_token}aaa" }
      it { is_expected.to have_http_status(:unauthorized) }
    end
  end
end
