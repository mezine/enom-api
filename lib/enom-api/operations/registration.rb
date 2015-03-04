module EnomAPI
  module Operations
    module Registration
      # Purchase a domain name.
      #
      # The returned hash has the following keys
      # - (Symbol) +:result+ --   Either +:registered+ or +:ordered+. The latter if the TLD does not support real time registrations.
      # - (String) +:order_id+ -- Order ID of the purchase
      #
      # @param [String] domain Domain name to register
      # @param [Registrant] registrant Registrant of the domain
      # @param [Array<String>, nil] nameservers Nameservers to set for the domain, nil sends blank NS1
      # @param [Hash] options Options to configure the registration
      # @option options [Integer] :Period Number of years to register the domain for
      # @option options [Integer] :RenewName 1 to automatically renew, 0 if otherwise
      # @return [Hash] :result => :registered and :order_id if successful
      # @return [Hash] :result => :ordered and :order_id if not a Real Time TLD
      # @raise [RuntimeError] if more than 12 nameservers are passed
      # @raise [ResponseError] if regisration failed
      def purchase(domain, registrant, nameservers, options = {})
        raise "Maximum nameserver limit is 12" if !nameservers.nil? && nameservers.size > 12
        opts = registrant.to_post_data('Registrant')
        opts[:NumYears] = options.delete(:Period) if options.has_key?(:Period)
        opts[:RenewName] = options.delete(:RenewName) if options.has_key?(:RenewName)

        xml = send_recv(:Purchase, split_domain(domain).merge(opts)) do |d|
          if nameservers.nil? || nameservers.empty?
            d['UseDNS'] = 'default'
          else
            nameservers.each_with_index do |n,i|
              d["NS#{i+1}"] = n
            end
          end
        end

        case xml.RRPCode.to_i
        when 200
          return { :result => :registered, :order_id => xml.OrderID }
        when 1300
          raise ResponseError.new([xml.RRPText]) if xml.IsRealTimeTLD?
          return { :result => :ordered, :order_id => xml.OrderID }
        end
      end

      # Purchases an addon service for a domain name
      # Currently only ID Protect (WPPS) is supported
      #
      # @param [String] domain Domain name to puchase a service for
      # @param [String] sevice The service type to purchase (currently only WPPS is supported)
      # @param [Hash] options Options to configure the service
      # @param options [Integer] :Period Number of years to register the domain for
      # @param options [Integer] :RenewName 1 to automatically renew, 0 if otherwise
      # @return [Boolean] True if successful
      def purchase_service(domain, service, options = {})
        raise "The specified service '#{service}' is not supported" unless service == 'WPPS'

        # Set some default options
        opts = {
          :Service => service
        }

        # Add any additional parameters, as needed
        opts[:NumYears] = options.delete(:Period) if options.has_key?(:Period)
        opts[:RenewName] = options.delete(:RenewName) if options.has_key?(:RenewName)

        xml = send_recv(:PurchaseServices, split_domain(domain).merge(opts))
        xml.Success?
      end


      # Deletes a domain registration.
      #
      # The domain registration must be less than 5 days old. eNom requires an +EndUserIP+
      # to be sent with the request, this is set to +127.0.0.1+.
      #
      # @param [String] domain Name of the registered domain
      # @return [true] if successfully deleted
      # @return [Hash] Error details with +:string+, +:source+ and +:section+ information
      def delete_registration(domain)
        xml = send_recv(:DeleteRegistration, split_domain(domain).merge(:EndUserIP => "127.000.000.001"))

        return true if xml.DomainDeleted?

        { :string => xml.ErrString,
          :source => xml.ErrSource,
          :section => xml.ErrSection }
      end

      # Get the list of extended attributes required by a TLD
      #
      # The returned array of extended attributes contains hashes of the attribute details.
      # The details include the following information
      # - (String) +:id+ --            eNom internal attribute ID
      # - (String) +:name+ --          Form parameter name
      # - (String) +:title+ --         Short definition of the parameter value
      # - (BOOL) +:application+ --     Attribute required for Registrant contact
      # - (BOOL) +:user_defined+ --    Attribute value must be provided by user
      # - (BOOL) +:required+ --        Attribute is required
      # - (String) +:description+ --   Long definition of the parameter value
      # - (String) +:is_child+ --      Is a child of another
      # - (Array) +:options+ --        Array of options for the attribute
      #
      # Attribute options include the following information
      # - (String) +:id+ --            eNom internal attribute option ID
      # - (String) +:value+ --         Value of the option
      # - (String) +:title+ --         Short definition of the parameter value
      # - (String) +:description+ --   Long definition of the parameter value
      #
      # @param [String] tld Top Level Domain
      # @return [Array] extended attributes, their details and valid options
      def get_ext_attributes(tld)
        xml = send_recv(:GetExtAttributes, :TLD => tld)

        attrs = []
        xml.Attributes do
          xml.Attribute do
            h = {
              :id => xml.ID,
              :name => xml.Name,
              :title => xml.Title,
              :application => xml.Application == '2',
              :user_defined => xml.UserDefined?,
              :required => xml.Required?,
              :description => xml.Description,
              :is_child => xml.IsChild?,
              :options => Array.new }
            attrs << h
            xml.Options do
              xml.Option do
                h[:options] << {
                  :id => xml.ID,
                  :value => xml.Value,
                  :title => xml.Title,
                  :description => xml.Description
                }
              end
            end
          end
        end
        attrs
      end

      # Set host records for a particular domain
      # @param [String] The domain name to set options for
      # @param [Hash] Array of Host Name, Record Type, Address values; e.g.
      # { :HostName1 => 'www', :RecordType1 => 'CNAME', :Address1 => 'app.herokuapp.com' }
      def set_hosts(domain, hosts)
        xml = send_recv(:SetHosts, split_domain(domain).merge(hosts))
        xml.Success?
      end

      # Resends the RAA notification for the given domain name
      def raa_resendnotification(domain)
        xml = send_recv(:RAA_ResendNotification, { :DomainName => domain })
        xml.Success?
      end
      
    end
  end
end
