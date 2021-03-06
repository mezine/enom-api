module EnomAPI
  module Operations
    module Contacts
      # Gets the WHOIS contact details for a domain
      #
      # The returned hash has the following keys
      # - (Hash<Symbol,Registrant>) +:contacts+ -- Registrant object
      # - (Time) +:updated_date+ --     Domain last update time
      # - (Time) +:created_date+ --     Domain creation date
      # - (Time) +:expiry_date+ --      Domain expiration date
      # - (Array) +:nameservers+ --     Array of name server names
      # - (String) +:status+ --         Registrar lock status
      #
      # @param [String] domain Domain name to retrieve WHOIS information for
      # @return [Hash] response data
      def get_whois_contact(domain)
        xml = send_recv(:GetWhoisContact, split_domain(domain))

        out = {:contacts => {}}
        xml.GetWhoisContacts do
          xml.contacts.contact do |contact,_|
            case contact['ContactType']
            when 'Registrant'
              out[:contacts][:registrant] = Registrant.from_xml(contact)
            when 'Administrative'
              out[:contacts][:administrative] = Registrant.from_xml(contact)
            when 'Technical'
              out[:contacts][:technical] = Registrant.from_xml(contact)
            when 'Billing'
              out[:contacts][:billing] = Registrant.from_xml(contact)
            end
          end

          xml.send("rrp-info") do
            upDate = xml.send("updated-date") rescue nil
            crDate = xml.send("created-date") rescue nil
            exDate = xml.send("registration-expiration-date") rescue nil

            out[:updated_date] = Time.parse(upDate) unless upDate.nil?
            out[:created_date] = Time.parse(crDate) unless crDate.nil?
            out[:expiry_date]  = Time.parse(exDate) unless exDate.nil?
            out[:nameservers]  = Array.new
            xml.nameserver do
              xml.nameserver do
                out[:nameservers] << xml.to_s.downcase
              end
            end
            xml.status do
              out[:status] = xml.status # != registration status from get_domain_info. = lock status
            end
          end
        end

        out
      end

      def get_contacts(domain)
        xml = send_recv(:GetContacts, split_domain(domain))
        xml = xml.GetContacts

        out = {}
        out[:registrant]      = Registrant.from_xml(xml.Registrant)
        out[:aux_billing]     = Registrant.from_xml(xml.AuxBilling)
        out[:administrative]  = Registrant.from_xml(xml.Admin)
        out[:technical]       = Registrant.from_xml(xml.Tech)
        out[:billing]         = Registrant.from_xml(xml.Billing)
        out
      end

      def contacts(domain, type, registrant)
        contact_type, prefix = case type
        when :registrant then ['REGISTRANT', 'Registrant']
        when :auxbilling then ['AUXBILLING', 'AuxBilling']
        when :admin      then ['ADMIN', 'Admin']
        when :tech       then ['TECH', 'Tech']
        end

        data = registrant.to_post_data(prefix)
        xml = send_recv(:Contacts, {:ContactType => contact_type}.merge(split_domain(domain)).merge(data))

        xml.ErrCount.to_i == 0
      end
    end
  end
end
