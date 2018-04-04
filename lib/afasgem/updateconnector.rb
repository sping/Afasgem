class UpdateConnector

	# Constructor, takes the connector name
	def initialize(name)
		@connectorname = name
		if Afasgem::debug
			# Build a debug client if the debug flag is set
			@client = Savon.client(
				wsdl: Afasgem::updateconnector_url,
				log: true,
				log_level: :debug,
				pretty_print_xml: true
			)
		else
			# Build a normal client otherwise
			@client = Savon.client(wsdl: Afasgem::updateconnector_url)
		end
	end

	# Method to return the savon client for this constructor
	def client
		return @client
	end

	# Executes an insert action using the passed object hash
	def insert(objecthash)
		xml = build_xml(objecthash, 'insert')
		return execute(xml)
	end

	# Executes an update action using the passed object hash
	def update(objecthash)
		xml = build_xml(objecthash, 'update')
		return execute(xml)
	end

	# Executes a delete action using the passed object hash
	def delete(objecthash)
		xml = build_xml(objecthash, 'delete')
		return execute(xml)
	end

	private

	# Builds the inner xml to send to the afas api from the passed hash and action
	def build_xml(objecthash, action)
		nested = []
		builder = Nokogiri::XML::Builder.new do |xml|
			xml.send('AfasEmployee'.to_sym, 'xmlns:xsi' => "http://www.w3.org/2001/XMLSchema-instance") {
				xml.Element {
					xml.Fields(Action: action) {
						objecthash.each do |k, v|
							xml.send(k.to_sym, v) unless k.to_s == 'Objects'
							if k.to_s == 'Objects'
								nested << [v, action]
								nil
							end
						end
					}
					nested.each do |a|
						build_nested_xml(xml, a[0], a[1])
					end
				}
			}
		end
		return builder.to_xml.to_s
	end

	# Builds the xml for nested objects
	def build_nested_xml(xml, objects, action)
		nested = []
		xml.Objects {
			objects.each do |obj, values|
				xml.send(obj) {
					xml.Element {
						xml.Fields(Action: action) {
							values.each do |k, v|
								xml.send(k.to_sym, v) unless k.to_s == 'Objects'
								if k.to_s == 'Objects'
									nested << [v, action]
									nil
								end
							end
						}
						nested.each do |a|
							build_nested_xml(xml, a[0], a[1])
						end
					}
				}
			end
		}
	end

	# Actually calls the afas api
	def execute(xml)
		message = {
			token: Afasgem.get_token,
			connectorType: @connectorname,
			connectorVersion: 1,
			dataXml: xml
		}
		resp = @client.call(:execute, message: message)
		return resp
	end
end
