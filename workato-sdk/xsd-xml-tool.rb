{
  title: "Dynamic XML Mapper",

  methods: {
    build_xml: lambda do |builder, key, value|
      if value.is_a?(Hash)
        # Extract attributes (keys starting with '@')
        attributes = value.select { |k, _| k.start_with?('@') }.transform_keys { |k| k[1..] } # Remove '@' prefix
        # Extract child elements (keys not starting with '@')
        elements = value.reject { |k, _| k.start_with?('@') }

        # Build the XML node with attributes and child elements
        builder.send(key, attributes) do
          elements.each { |k, v| call(:build_xml, builder, k, v) }
        end
      elsif value.is_a?(Array)
        # Handle arrays by creating multiple child elements without wrapping in <item>
        value.each do |item|
          call(:build_xml, builder, key, item)
        end
      else
        # Handle simple text nodes
        builder.send(key, value)
      end
    end
  },

  connection: {
    fields: [],
    authorization: nil
  },

  test: lambda do |connection|
    true
  end,

  actions: {
    generate_xml_from_example: {
      title: "Generate XML from Example",
      description: "Map to XML data from an XML example",

      config_fields: [
        { name: "xml_example", label: "XML Example Input", type: "string", optional: false },
      ],

      input_fields: lambda do |object_definitions, connection, config_fields|
        object_definitions['xml_input_schema']
      end,

      execute: lambda do |connection, input|
        # Extract the root element name from the xml_example input
        xml_example = input.delete("xml_example") # Remove xml_example from input
        require 'nokogiri'
        parsed_xml = Nokogiri::XML(xml_example)
        root_element_name = parsed_xml.root.name # Get the root element name dynamically

        # Build the XML string
        xml_string = Nokogiri::XML::Builder.new do |builder|
          builder.send(root_element_name) do # Use the dynamic root element
            input.each do |key, value|
              call(:build_xml, builder, key, value)
            end
          end
        end.to_xml

        { xml_output: xml_string } # Wrap the XML string in a hash
      end,

      output_fields: lambda do |object_definitions, connection, config_fields|
        [{ name: "xml_output", label: "XML Output", type: "string", control_type: "text" }]
      end,
    },
    
    generate_xml_from_schema: {
      title: "Generate XML from Schema",
      description: "Parses an XSD Schema and map to XML data",

      config_fields: [
        { name: "xsd_schema", label: "XSD Schema", type: "string", optional: false },
      ],

      input_fields: lambda do |object_definitions, connection, config_fields|
        object_definitions['xsd_input_schema']
      end,

      execute: lambda do |connection, input|
        # Extract the root element name from the XSD schema
        require 'nokogiri'
        xsd_schema = Nokogiri::XML(input.delete("xsd_schema")) # Remove xsd_schema from input
        root_element_name = xsd_schema.at_xpath("//xs:element", xs: "http://www.w3.org/2001/XMLSchema")['name']

        # Build the XML string
        xml_string = Nokogiri::XML::Builder.new do |builder|
          builder.send(root_element_name) do # Use the dynamic root element
            input.each do |key, value|
              call(:build_xml, builder, key, value)
            end
          end
        end.to_xml

        { xml_output: xml_string } # Wrap the XML string in a hash
      end,

      output_fields: lambda do |object_definitions, connection, config_fields|
        [{ name: "xml_output", label: "XML Output", type: "string", control_type: "text" }]
      end,
    }
  },

  object_definitions: {
    xml_input_schema: {
      fields: lambda do |connection, config_fields, object_definitions|
        # Parse XML example to generate schema fields
        raise "XML Example Input is required" if config_fields['xml_example'].blank?

        require 'nokogiri'
        parsed_xml = Nokogiri::XML(config_fields['xml_example'])
        raise "Invalid XML input" if parsed_xml.root.nil?

        # Generate schema
        generate_fields = lambda do |node|
          child_nodes = node.element_children.group_by(&:name)
          attributes = node.attributes.map do |attr_name, attr|
            {
              name: "@#{attr_name}",
              type: "string"
            }
          end

          {
            name: node.name,
            type: node.element_children.empty? ? "string" : "object",
            properties: attributes + child_nodes.map do |name, children|
              if children.size > 1
                { name: name, type: "array", of: "object", properties: generate_fields.call(children.first)[:properties] }
              else
                generate_fields.call(children.first)
              end
            end
          }
        end

        parsed_xml.root.element_children.group_by(&:name).map do |name, children|
          if children.size > 1
            { name: name, type: "array", of: "object", properties: generate_fields.call(children.first)[:properties] }
          else
            generate_fields.call(children.first)
          end
        end
      end
    },
    xsd_input_schema: {
      fields: lambda do |connection, config_fields, object_definitions|
        raise "XSD Input is required" if config_fields['xsd_schema'].blank?

        require 'nokogiri'
        xsd = Nokogiri::XML(config_fields['xsd_schema'])
        raise "Invalid XSD input" if xsd.root.nil?

        # Generate schema from XSD
        generate_fields = lambda do |node|
          # Skip nodes without a 'name' attribute unless they are root elements
          return nil if node['name'].nil? && node.name != 'element'

          # Resolve complexType references
          if node['type']
            type_name = node['type'].split(':').last
            type_node = xsd.at_xpath("//xs:complexType[@name='#{type_name}']", xs: "http://www.w3.org/2001/XMLSchema")
            return generate_fields.call(type_node) if type_node
          end

          # Handle complexType or sequence directly within the node
          properties = []
          node.xpath("xs:complexType/*", xs: "http://www.w3.org/2001/XMLSchema").each do |child|
            if child.name == 'sequence'
              # Process child elements in the sequence
              child.xpath("xs:element", xs: "http://www.w3.org/2001/XMLSchema").each do |element|
                properties << generate_fields.call(element)
              end
            elsif child.name == 'attribute'
              # Process attributes
              properties << {
                name: "@#{child['name']}", # Prefix attribute names with '@'
                type: child['type'] ? child['type'].split(':').last : 'string'
              }
            end
          end

          # Determine the type of the current node
          type = if node.name == 'complexType' || properties.any?
                   'object'
                 elsif node.name == 'simpleType'
                   'string'
                 else
                   'string'
                 end

          # Handle maxOccurs for lists
          if node['maxOccurs'] && node['maxOccurs'] != '1'
            {
              name: node['name'],
              type: 'array',
              of: 'object',
              properties: properties.compact # Remove nil entries
            }
          else
            # Combine properties into the schema
            {
              name: node['name'],
              type: type,
              properties: properties.compact # Remove nil entries
            }
          end
        end

        # Parse the XSD and generate the schema
        root_element = xsd.at_xpath("//xs:element", xs: "http://www.w3.org/2001/XMLSchema")
        [generate_fields.call(root_element)].compact # Ensure only the root element is included
      end
    }
  }
}