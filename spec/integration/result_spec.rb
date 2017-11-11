RSpec.describe(Dry::Monads::Result) do
  result = described_class

  include Dry::Monads::Result::Mixin

  describe 'matching' do
    let(:match) do
      -> value do
        case value
        when Success('foo') then :foo_eql
        when Success(/\w+/) then :bar_rg
        when Success(42) then :int_match
        when Success(10..50) then :int_range
        when Success(-> x { x > 9000 }) then :int_proc_arg
        when Success { |x| x > 100 } then :int_proc_block
        when Failure(10) then :ten_eql
        when Failure(/\w+/) then :failure_rg
        when Failure { |x| x > 90 } then :failure_block
        else
          :else
        end
      end
    end

    it 'can be used in a case statement' do
      expect(match.(Success('foo'))).to eql(:foo_eql)
      expect(match.(Success('bar'))).to eql(:bar_rg)
      expect(match.(Success(42))).to eql(:int_match)
      expect(match.(Success(42.0))).to eql(:int_match)
      expect(match.(Success(12))).to eql(:int_range)
      expect(match.(Success(9123))).to eql(:int_proc_arg)
      expect(match.(Success(144))).to eql(:int_proc_block)
      expect(match.(Failure(10))).to eql(:ten_eql)
      expect(match.(Failure('foo'))).to eql(:failure_rg)
      expect(match.(Failure(100))).to eql(:failure_block)
      expect(match.(Success(-1))).to eql(:else)
    end
  end
end
