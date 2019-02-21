class BaseConnector
  
  def get_client(connector_url)
    client_params = {wsdl: connector_url}
    if Afasgem::debug || !Afasgem::payload_logger.nil?
      client_params[:log] = true
      client_params[:log_level] = :debug
      client_params[:pretty_print_xml] = true
    end
    client_params[:logger] = Afasgem::payload_logger unless Afasgem::payload_logger.nil?
    Savon.client(client_params)
  end

end