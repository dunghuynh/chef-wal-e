require 'spec_helper'

describe 'wal-e::default' do

  before do
    Chef::Config[:config_file] = '/dev/null'
    stub_data_bag_item('aws_credentials', 'wal_e').and_return({
      secret_access_key: 'secret',
      access_key_id: 'secret_access_key',
      bucket: 'eve',
    })
  end

  let(:chef_run) do
    ChefSpec::Runner.new.converge described_recipe
  end

  context 'with default attributes' do
    it 'loads python::default recipe' do
      expect(chef_run).to include_recipe 'python::default'
    end

    it 'loads runit::default recipe' do
      expect(chef_run).to include_recipe 'runit::default'
    end

    it 'installs package lzop' do
      expect(chef_run).to install_package 'lzop'
    end

    it 'installs package pv' do
      expect(chef_run).to install_package 'pv'
    end

    it 'installs package libevent-dev' do
      expect(chef_run).to install_package 'libevent-dev'
    end

    it 'creates a python virtualenv for wal-e' do
      expect(chef_run).to create_python_virtualenv('/opt/wal-e/').with(
        owner: 'root',
        group: 'postgres'
      )
    end

    it 'installs wal-e via pip in virtualenv' do
      expect(chef_run).to install_python_pip('wal-e').with(
        virtualenv: '/opt/wal-e/',
        version: '0.7.1'
      )
    end

    it 'creates base directory for configs' do
      expect(chef_run).to create_directory('/etc/wal-e.d/').with(
        owner: 'root',
        group: 'postgres',
        mode: '0750'
      )
    end

    it 'creates env directory for configs' do
      expect(chef_run).to create_directory('/etc/wal-e.d/env').with(
        owner: 'root',
        group: 'postgres',
        mode: '0750'
      )
    end

    it 'creates file for AWS_SECRET_ACCESS_KEY' do
      expect(chef_run).to create_file(
        '/etc/wal-e.d/env/AWS_SECRET_ACCESS_KEY'
      ).with(
        owner: 'root',
        group: 'postgres',
        mode: '0750',
      )
      expect(chef_run).to render_file(
        '/etc/wal-e.d/env/AWS_SECRET_ACCESS_KEY'
      ).with_content 'secret'
    end

    it 'creates file for AWS_ACCESS_KEY_ID' do
      expect(chef_run).to create_file(
        '/etc/wal-e.d/env/AWS_ACCESS_KEY_ID'
      ).with(
        owner: 'root',
        group: 'postgres',
        mode: '0750',
      )
      expect(chef_run).to render_file(
        '/etc/wal-e.d/env/AWS_ACCESS_KEY_ID'
      ).with_content 'secret_access_key'
    end

    it 'creates file for WALE_S3_PREFIX' do
      expect(chef_run).to create_file(
        '/etc/wal-e.d/env/WALE_S3_PREFIX'
      ).with(
        owner: 'root',
        group: 'postgres',
        mode: '0750',
      )
      expect(chef_run).to render_file(
        '/etc/wal-e.d/env/WALE_S3_PREFIX'
      ).with_content 's3://eve/fauxhai.local/wal-e'
    end

    it 'creates file for WALE_GPG_KEY_ID' do
      expect(chef_run).to create_file(
        '/etc/wal-e.d/env/WALE_GPG_KEY_ID'
      ).with(
        owner: 'root',
        group: 'postgres',
        mode: '0750',
      )
      expect(chef_run).to render_file(
        '/etc/wal-e.d/env/WALE_GPG_KEY_ID'
      ).with_content ""
    end

    it 'deletes /etc/boto.cfg' do
      expect(chef_run).to delete_file '/etc/boto.cfg'
    end
  end

  context 'setting an s3 default host' do
    let(:chef_run) do
      ChefSpec::Runner.new do |node|
        node.set['wal-e']['s3']['default_host'] = 's3_default_host'
      end.converge described_recipe
    end

    it 'creates a boto config file' do
      expect(chef_run).to create_template('/etc/boto.cfg').with(
        owner: 'root',
        group: 'postgres',
        mode: '0750',
      )
    end

    it 'sets the default host from attribute' do
      expect(chef_run).to render_file('/etc/boto.cfg').with_content(
        /\[s3\]\nhost=s3_default_host/
      )
    end
  end

  context 'using encrypted databag' do

    before do
      allow(Chef::EncryptedDataBagItem).to receive(:load).with(
        'aws_credentials', 'wal_e_encrypted'
      ).and_return({
        'secret_access_key' => 'secret_from_encrypted',
        'access_key_id' => 'secret_access_key_from_encrypted',
        'bucket' => 'eve_from_encrypted',
      })
    end

    let(:chef_run) do
      ChefSpec::Runner.new do |node|
        node.set['wal-e']['s3']['use_encrypted_data_bag'] = true
        node.set['wal-e']['s3']['data_bag_item'] = 'wal_e_encrypted'
      end.converge described_recipe
    end

    it 'creates file for AWS_SECRET_ACCESS_KEY' do
      expect(chef_run).to create_file(
        '/etc/wal-e.d/env/AWS_SECRET_ACCESS_KEY'
      ).with(
        owner: 'root',
        group: 'postgres',
        mode: '0750',
      )
      expect(chef_run).to render_file(
        '/etc/wal-e.d/env/AWS_SECRET_ACCESS_KEY'
      ).with_content 'secret_from_encrypted'
    end

    it 'creates file for AWS_ACCESS_KEY_ID' do
      expect(chef_run).to create_file(
        '/etc/wal-e.d/env/AWS_ACCESS_KEY_ID'
      ).with(
        owner: 'root',
        group: 'postgres',
        mode: '0750',
      )
      expect(chef_run).to render_file(
        '/etc/wal-e.d/env/AWS_ACCESS_KEY_ID'
      ).with_content 'secret_access_key_from_encrypted'
    end

    it 'creates file for WALE_S3_PREFIX' do
      expect(chef_run).to create_file(
        '/etc/wal-e.d/env/WALE_S3_PREFIX'
      ).with(
        owner: 'root',
        group: 'postgres',
        mode: '0750',
      )
      expect(chef_run).to render_file(
        '/etc/wal-e.d/env/WALE_S3_PREFIX'
      ).with_content 's3://eve_from_encrypted/fauxhai.local/wal-e'
    end

  end

end
