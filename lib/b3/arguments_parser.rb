require 'parslet'

module B3
  class ArgumentsParser < Parslet::Parser
    root(:argument_list)

    rule(:argument_list) {
      data_structure >> space? >> separator? >> space? >> argument_list.repeat
    }

    rule(:data_structure) { array | object | integer | string | address | null | flag_list }

    # whitespace
    rule(:space) { match(/\s/).repeat(1) }
    rule(:space?) { match(/\s/).repeat(1).maybe }

    # separators
    rule(:separator) { match(',') }
    rule(:separator?) { match(',').maybe }

    # arrays
    rule(:array) {
      str('[') >> (
        str('[').absent? >> array_element
      ).repeat.as(:array_elements) >> str(']')
    }
    rule(:array_element) { space? >> data_structure.as(:array_element) >> space? >> separator? }

    # objects
    rule(:object) {
      str('{') >> (
      str('{').absent? >> property
      ).repeat.as(:properties) >> str('}')
    }

    rule(:property_key) { match(/[a-zA-Z][_a-zA-Z0-9'"]*/).repeat(1) }
    rule(:property_value) { data_structure.repeat }
    rule(:property) { space? >> property_key.as(:key) >> space? >> str('=') >> space? >> property_value.as(:value) >> space? }

    # ints (match integers not followed by 'x' - for address)
    rule(:integer) { match(/-?[0-9]/).repeat(1).as(:integer) >> str('x').absent? }

    # addresses
    rule(:address) { (str('0x') >> match(/[0-9a-fA-F]/).repeat(1)).as(:address) }

    # strings
    rule(:string) { single_quoted_string | double_quoted_string }
    rule(:double_quoted_string) {
      str('"') >> (
        str('\\').ignore >> any |
        str('"').absent? >> any
      ).repeat.as(:string) >> str('"')
    }
    rule(:single_quoted_string) {
      str("'") >> (
        str('\\').ignore >> any |
        str("'").absent? >> any
      ).repeat.as(:string) >> str("'")
    }

    # flags/flags
    rule(:flags) { match(/[_A-Z][_A-Z0-9]*/).repeat(1) >> str('|').maybe >> flags.repeat }
    rule(:flag_list) { flags.as(:flag_list) }

    rule(:null) { str('NULL').as(:null) }

    def self.execute(arguments_str)
      parsed = self.new.parse(arguments_str)
      transform_result(parsed)
    rescue Parslet::ParseFailed => e
      puts e.parse_failure_cause.ascii_tree
      raise e
    end

    private

    def self.transform_result(parsed)
      transformed = Transformer.new.apply(parsed)

      # always return result as an array
      transformed = [transformed] unless transformed.is_a?(Array)
      transformed.freeze
    end
  end

  class Transformer < Parslet::Transform
    rule(:integer => simple(:x)) { Integer(x) }
    rule(:string => simple(:x)) { x }
    rule(:flag_list => simple(:x)) { x }
    rule(:array_element => simple(:x)) { x }
    rule(:array_elements => sequence(:x)) { x }
    rule(:null => simple(:x)) { nil }
  end
end