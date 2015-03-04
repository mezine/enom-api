module EnomAPI
  module Operations
    module Renewal
      # Get the expiration date of a domain
      #
      # @param [String] domain Domain name
      # @return [Time] expiration date of the domain in UTC
      def get_domain_exp(domain)
        xml = send_recv(:GetDomainExp, split_domain(domain))
        fmt = "%m/%d/%Y %l:%M:%S %p %z"
        str = "%s %s" % [xml.ExpirationDate.strip, xml.TimeDifference.strip]

        if Time.respond_to?(:strptime)
          Time.strptime(str, fmt).utc
        else
          dt = DateTime.strptime(str, fmt).new_offset(0)  # UTC time
          Time.utc(dt.year, dt.mon, dt.mday, dt.hour, dt.min, dt.sec + dt.sec_fraction)
        end
      end

      # Get a list of the domains in the Expired, Redemption and Extended Redemption groups.
      #
      # The returned hash has the following keys
      # - (Array) +:expired+ -- Expired domains
      # - (Array) +:redemption+ -- Domains in Redemption Grace Period (RGP)
      # - (Array) +:extended_redemption+ -- Domains in Extended RGP
      #
      # Each array contains hashes with the following keys
      # - (String) +:name+ -- The domain name
      # - (String) +:id+ -- The domains eNom registry ID
      # - (Time) +:date+ -- Expiration date of the domain
      # - (BOOL) +:locked+ -- Domain locked status
      #
      # @return [Hash] Hash of expired domains information
      def get_expired_domains
        xml = send_recv(:GetExpiredDomains)

        domains = {:expired => [], :extended_redemption => [], :redemption => []}
        xml.DomainDetail do
          case xml.status
          when /Expired/i
            domains[:expired]
          when /Extended RGP/i
            domains[:extended_redemption]
          when /RGP/i
            domains[:redemption]
          end << {
            :name => xml.DomainName,
            :id => xml.DomainNameID,
            :date => Time.parse(xml.send('expiration-date')),
            :locked => xml.lockstatus =~ /Locked/i
          }
        end
        domains
      end

      # @param [String] domain Domain name to renew
      # @param [String] period Number of years to extend the registration by
      # @return [String] Order ID of the renewal
      # @return [false] the order did not succeed
      def extend(domain, period = 1)
        xml = send_recv(:Extend, split_domain(domain).merge(:NumYears => period.to_i))

        return false if xml.RRPCode != '200'
        xml.OrderID
      end

      # Get renewal information for a domain
      #
      # The returned hash contains the following keys
      # - (Time) +:expiration+ --       Time the domain expires
      # - (Integer) +:max_extension+ -- Maximum number of years which can be added
      # - (Integer) +:min_extension+ -- Minimum number of years which can be added
      # - (BOOL) +:registrar_hold+ --   Registrar hold state
      # - (Float) +:balance+ --         Current account balance
      # - (Float) +:available+ --       Available account balance
      #
      # @param [String] domain Domain name
      # @return [Hash] Renewal information
      def get_extend_info(domain)
        xml = send_recv(:GetExtendInfo, split_domain(domain))

        { :expiration => Time.parse(xml.Expiration),
          :max_extension => xml.MaxExtension.to_i,
          :min_extension => xml.MinAllowed.to_i,
          :registrar_hold => xml.RegistrarHold?,
          :balance => xml.Balance.to_f,
          :available => xml.AvailableBalance.to_f }
      end

      # Reactivates an expired domain in real time.
      #
      # @param [String] domain Expired Domain name to register
      # @param [Number] years Number of years to register the domain for
      # @return [String] response status
      def update_expired_domains(domain, years = 1) # Like :extend, but for expired domains
        xml = send_recv(:UpdateExpiredDomains, :DomainName => domain, :NumYears => years.to_i)
        xml = xml.ReactivateDomainName

        return false unless xml.Status?
        xml.OrderID
      end

      # Set whether this domain should continue to renew past its expiry date
      # @param [String] The domain name to set the renew option for
      # @param [Integer] 1 to auto-renew, 0 otherwise
      def set_renew(domain, renew)
        raise ArgumentError, "invalid renew type - `#{renew}' (must be 1 or 0)" unless renew.is_a?(Integer) && [0, 1].include?(renew)
        xml = send_recv(:SetRenew, split_domain(domain).merge({
          :RenewFlag => renew
        }))
        xml.Success?
      end
    end
  end
end
