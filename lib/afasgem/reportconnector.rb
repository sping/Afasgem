class ReportConnector < BaseConnector

  # Constructor, takes the connector name
  def initialize(name)
    @connectorname = name
    @filters = []
    @client = get_client(Afasgem::reportconnector_url)
  end

  # Method to return the savon client for this constructor
  def client
    return @client
  end

  # Adds a filter to the current filter list
  # Provides a fluent interface
  def add_filter(field, operator, value = nil)
    if @filters.size == 0
      @filters.push([])
    end

    # Only the EMPTY and NOT_EMPTY filters should accept a nil value
    if !value
      unless operator == FilterOperators::EMPTY || operator == FilterOperators::NOT_EMPTY
        raise ArgumentError.new('Value can only be empty when using FilterOperator::EMPTY or FilterOperator::NOT_EMPTY')
      end
    end
    @filters.last.push({field: field, operator: operator, value: value})
    return self
  end

  # Clears the filters in place
  # Provides a fluent interface
  def clear_filters
    @filters = []
    return self
  end

  def get_data(report_id)
    execute(report_id) unless @result
    @result
  end

  def execute(report_id)
    @result = execute_request(report_id)
    return self
  end

  def execute_request(report_id)
    message = {
      token: Afasgem.get_token,
      reportID: report_id,
      parametersXml: ""
    }

    filter_string = get_filter_string
    message[:filtersXml] = filter_string if filter_string

    resp = @client.call(:execute, message: message)
    resp.hash[:envelope][:body][:execute_response][:execute_result]
  end

  # Returns the filter xml in string format
  def get_filter_string
    return nil if @filters.size == 0
    filters = []

    # Loop over each filtergroup
    # All conditions in a filtergroup are combined using AND
    # All filtergroups are combined using OR
    @filters.each_with_index do |filter, index|
      fields = []

      # Loop over all conditions in a filter group
      filter.each do |condition|
        field = condition[:field]
        operator = condition[:operator]
        value = condition[:value]

        # Some filters operate on strings and need wildcards
        # Transform value if needed
        case operator
          when FilterOperators::LIKE
            value = "%#{value}%"
          when FilterOperators::STARTS_WITH
            value = "#{value}%"
          when FilterOperators::NOT_LIKE
            value = "%#{value}%"
          when FilterOperators::NOT_STARTS_WITH
            value = "#{value}%"
          when FilterOperators::ENDS_WITH
            value = "%#{value}"
          when FilterOperators::NOT_ENDS_WITH
            value = "%#{value}"
          when FilterOperators::EMPTY
            # EMPTY and NOT_EMPTY operators require the filter to be in a different format
            # This because they take no value
            fields.push("<Field FieldId=\"#{field}\" OperatorType=\"#{operator}\" />")
            next
          when FilterOperators::NOT_EMPTY
            fields.push("<Field FieldId=\"#{field}\" OperatorType=\"#{operator}\" />")
            next
        end

        # Add this filterstring to filters
        fields.push("<Field FieldId=\"#{field}\" OperatorType=\"#{operator}\">#{value}</Field>")
      end

      # Make sure all filtergroups are OR'ed and add them
      filters.push("<Filter FilterId=\"Filter #{index}\">#{fields.join}</Filter>")
    end

    # Return the whole filterstring
    return "<Filters>#{filters.join}</Filters>"
  end

  # Source of code below: https://gist.github.com/huy/819999
  def from_xml(xml_io)
    begin
      result = Nokogiri::XML(xml_io)
      return { result.root.name.to_sym => xml_node_to_hash(result.root)}
    rescue Exception => e
      # raise your custom exception here
    end
  end

  def xml_node_to_hash(node)
    # If we are at the root of the document, start the hash
    if node.element?
      result_hash = {}
      if node.attributes != {}
        attributes = {}
        node.attributes.keys.each do |key|
          attributes[node.attributes[key].name.to_sym] = node.attributes[key].value
        end
      end
      if node.children.size > 0
        node.children.each do |child|
          result = xml_node_to_hash(child)

          if child.name == "text"
            unless child.next_sibling || child.previous_sibling
              return result unless attributes
              result_hash[child.name.to_sym] = result
            end
          elsif result_hash[child.name.to_sym]

            if result_hash[child.name.to_sym].is_a?(Object::Array)
              result_hash[child.name.to_sym] << result
            else
              result_hash[child.name.to_sym] = [result_hash[child.name.to_sym]] << result
            end
          else
            result_hash[child.name.to_sym] = result
          end
        end
        if attributes
          #add code to remove non-data attributes e.g. xml schema, namespace here
          #if there is a collision then node content supersets attributes
          result_hash = attributes.merge(result_hash)
        end
        return result_hash
      else
        return attributes
      end
    else
      return node.content.to_s
    end
  end
end
