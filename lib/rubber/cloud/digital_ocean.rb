require 'rubber/cloud/fog'

module Rubber
  module Cloud

    class DigitalOcean < Fog

      def initialize(env, capistrano)
        compute_credentials = {
          :provider => 'DigitalOcean',
          :digitalocean_api_key => env.api_key,
          :digitalocean_client_id => env.client_key
        }

        if env.cloud_providers && env.cloud_providers.aws
          storage_credentials = {
            :provider => 'AWS',
            :aws_access_key_id => env.cloud_providers.aws.access_key,
            :aws_secret_access_key => env.cloud_providers.aws.secret_access_key,
            :path_style => true
          }

          storage_credentials[:region] = env.cloud_providers.aws.region

          env['storage_credentials'] = storage_credentials
        end

        env['compute_credentials'] = compute_credentials
        super(env, capistrano)
      end

      # As of October 2014 Digital Ocean supports private networking in
      # New York 2 (id 4), New York 3 (id 8), Amsterdam 2 (id 5), Amsterdam 3 (id 9), Singapore 1 (id 6) and London 1 (id 7)
      REGIONS_WITH_PRIVATE_NETWORKING = [4, 5, 6, 7, 8, 9]

      def create_instance(instance_alias, image_name, image_type, security_groups, availability_zone, region, fog_options={})
        do_region = compute_provider.regions.find { |r| r.name == region }
        if do_region.nil?
          raise "Invalid region for DigitalOcean: #{region}"
        end

        if env.private_networking && ! REGIONS_WITH_PRIVATE_NETWORKING.include?(do_region.id)
          raise "Private networking is enabled, but region #{region} does not support it"
        end

        image = compute_provider.images.find { |i| i.name == image_name }
        if image.nil?
          raise "Invalid image name for DigitalOcean: #{image_name}"
        end

        flavor = compute_provider.flavors.find { |f| f.name == image_type }
        if flavor.nil?
          raise "Invalid image type for DigitalOcean: #{image_type}"
        end

        # Check if the SSH key has been added to DigitalOcean yet.
        # TODO (nirvdrum 03/23/13): DigitalOcean has an API for getting a single SSH key, but it hasn't been added to fog yet.  We should add it.
        ssh_key = compute_provider.list_ssh_keys.body['ssh_keys'].find { |key| key['name'] == env.key_name }
        if ssh_key.nil?
          if env.key_file
            compute_provider.create_ssh_key(env.key_name, File.read("#{env.key_file}.pub"))

            # Although not documented, DigitalOcean is eventually consistent.  Receiving a 200 response with the key
            # body does not mean the key has propagated through their systems yet.  Thus we need to query to see if
            # the key is yet available.  Otherwise our request will end up creating a droplet without an attached key.

            begin
              sleep(0.5)
              ssh_key = compute_provider.list_ssh_keys.body['ssh_keys'].find { |key| key['name'] == env.key_name }
            end while ssh_key.nil?

          else
            raise 'Missing key_file for DigitalOcean'
          end
        end

        response = compute_provider.servers.create({:name => "#{Rubber.env}-#{instance_alias}",
                                                   :image_id => image.id,
                                                   :flavor_id => flavor.id,
                                                   :region_id => do_region.id,
                                                   :ssh_key_ids => [ssh_key['id']],
                                                   :private_networking => (env.private_networking.to_s.downcase == 'true')}.
                                                   merge(Rubber::Util.symbolize_keys(fog_options))
        )

        response.id
      end

      def describe_instances(instance_id=nil)
        instances = []
        opts = {}

        if instance_id
          response = [compute_provider.servers.get(instance_id)]
        else
          response = compute_provider.servers.all(opts)
        end

        response.each do |item|
          instance = {}
          instance[:id] = item.id
          instance[:state] = item.state
          instance[:type] = item.flavor_id
          instance[:external_ip] = item.public_ip_address
          instance[:internal_ip] = item.private_ip_address || item.public_ip_address
          instance[:region_id] = item.region_id
          instance[:provider] = 'digital_ocean'
          instance[:platform] = Rubber::Platforms::LINUX
          instances << instance
        end

        return instances
      end

      def active_state
        'active'
      end
    end
  end
end
