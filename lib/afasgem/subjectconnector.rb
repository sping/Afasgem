class SubjectConnector < BaseConnector

  # Constructor, takes the connector name
  def initialize(name)
    @connectorname = name
    @filters = []
    @client = get_client(Afasgem::subjectconnector_url)
  end

  # Method to return the savon client for this constructor
  def client
    return @client
  end

  def get_data(subject_id, attachment_id)
    execute(subject_id, attachment_id) unless @result
    @result
  end

  def execute(subject_id, attachment_id)
    @result = execute_request(subject_id, attachment_id)
    return self
  end

  def execute_request(subject_id, attachment_id)
    message = {
      token: Afasgem.get_token,
      subjectID: subject_id,
      fileId: attachment_id
    }

    resp = @client.call(:get_attachment, message: message)
    resp.hash[:envelope][:body][:get_attachment_response][:get_attachment_result]
  end
end
