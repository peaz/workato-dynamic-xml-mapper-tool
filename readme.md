# Dynamic XML Mapper - Workato Custom SDK

This Workato Custom SDK provides functionality to dynamically generate XML documents based on either an XML example or an XSD schema. It is designed to simplify the process of mapping data to XML structures, making it easier to work with complex XML schemas.

## Features

- **Generate XML from Example**: Automatically map data to an XML structure based on an example XML input.
- **Generate XML from Schema**: Parse an XSD schema to dynamically generate XML structures and map data accordingly.
- **Support for Attributes**: Handles XML attributes (e.g., `@id`) seamlessly.
- **Support for Arrays**: Automatically detects and handles repeating elements (e.g., `maxOccurs="unbounded"`).
- **Nested Structures**: Supports deeply nested XML structures with complex types and sequences.

## Actions

### 1. Generate XML from Example

This action generates an XML document based on an example XML input.

#### Configuration Fields
- **`xml_example`**: (Required) The XML example input used to generate the schema.

#### Input Fields
- Dynamically generated based on the structure of the provided XML example.

#### Output Fields
- **`xml_output`**: The generated XML document as a string.

---

### 2. Generate XML from Schema

This action generates an XML document based on an XSD schema.

#### Configuration Fields
- **`xsd_schema`**: (Required) The XSD schema used to generate the XML structure.

#### Input Fields
- Dynamically generated based on the structure of the provided XSD schema.

#### Output Fields
- **`xml_output`**: The generated XML document as a string.

---

## Object Definitions

### `xml_input_schema`
- Dynamically generates schema fields based on the provided XML example.

### `xsd_input_schema`
- Dynamically generates schema fields based on the provided XSD schema.
- Supports attributes (e.g., `@id`) and nested structures.
- Handles repeating elements (`maxOccurs`).

---

## Methods

### `build_xml`
A recursive method used to construct XML documents from the input data. It:
- Handles attributes (keys prefixed with `@`).
- Processes arrays as repeating elements.
- Builds nested XML structures.

---

## Example Usage

### Example 1: Generate XML from Example

#### Input
```json
{
  "xml_example": "<persons><person><firstName>John</firstName><lastName>Doe</lastName></person></persons>",
  "person": {
    "firstName": "Jane",
    "lastName": "Smith"
  }
}
```

#### Output
```xml
<persons>
  <person>
    <firstName>Jane</firstName>
    <lastName>Smith</lastName>
  </person>
</persons>
```

---

### Example 2: Generate XML from Schema

#### Input
```json
{
  "xsd_schema": "<xs:schema xmlns:xs='http://www.w3.org/2001/XMLSchema'>...</xs:schema>",
  "person": {
    "@id": "1",
    "firstName": "John",
    "lastName": "Doe",
    "orders": {
      "order": [
        {
          "orderDate": "2023-01-01",
          "orderNumber": "ORD12345",
          "totalAmount": "150.75"
        }
      ]
    }
  }
}
```

#### Output
```xml
<persons>
  <person id="1">
    <firstName>John</firstName>
    <lastName>Doe</lastName>
    <orders>
      <order>
        <orderDate>2023-01-01</orderDate>
        <orderNumber>ORD12345</orderNumber>
        <totalAmount>150.75</totalAmount>
      </order>
    </orders>
  </person>
</persons>
```

---

## Prerequisites

- **Workato Account**: Ensure you have access to Workato's Custom SDK feature.
- **Ruby**: The SDK uses Ruby for its implementation.

---

## Installation

1. Go to [Dynamic XML Mapper custom connector page](https://app.workato.com/custom_adapters/932640?token=50d8f8a96bef0ac2932543174e69c26686eeb01ae2c6f06c252e4370c3bde531).
2. Install the connector to your own workspace.
3. Release the connector for use in your workspace.

## Create your own

1. Copy the SDK source code from [xsd-xml-tool.rb](/workato-sdk/xsd-xml-tool.rb)
2. Upload the `xsd-xml-tool.rb` file to your Workato Custom SDK.

---

## Testing

- Use the provided `persons.xsd` and `persons.xml` files to test the functionality.
- Validate the generated XML against the XSD schema using an XML validator.

---

## License

This project is licensed under the MIT License. See the LICENSE file for details.

---

## Contributing

Contributions are welcome! Please submit a pull request or open an issue for any bugs or feature requests.