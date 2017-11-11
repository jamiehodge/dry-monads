RSpec.describe(Dry::Monads::Result) do
  mresult = described_class
  maybe = Dry::Monads::Maybe
  some = maybe::Some.method(:new)
  failure = mresult::Failure.method(:new)
  success = mresult::Success.method(:new)

  let(:upcase) { :upcase.to_proc }

  describe mresult::Success do
    subject { success['foo'] }

    let(:upcased_subject) { success['FOO'] }

    it { is_expected.to be_success }

    it { is_expected.not_to be_failure }

    it { is_expected.to eql(described_class.new('foo')) }
    it { is_expected.not_to eql(failure['foo']) }

    it 'dumps to string' do
      expect(subject.to_s).to eql('Success("foo")')
    end

    it 'has custom inspection' do
      expect(subject.inspect).to eql('Success("foo")')
    end

    describe '#bind' do
      it 'accepts a proc and does not lift the result' do
        expect(subject.bind(upcase)).to eql('FOO')
      end

      it 'accepts a block too' do
        expect(subject.bind { |s| s.upcase }).to eql('FOO')
      end

      it 'passes extra arguments to a block' do
        result = subject.bind(:foo) do |value, c|
          expect(value).to eql('foo')
          expect(c).to eql(:foo)
          true
        end

        expect(result).to be true
      end

      it 'passes extra arguments to a proc' do
        proc = lambda do |value, c|
          expect(value).to eql('foo')
          expect(c).to eql(:foo)
          true
        end

        result = subject.bind(proc, :foo)

        expect(result).to be true
      end
    end

    describe '#result' do
      subject do
        mresult::Success.new('Foo').result(
          lambda { |v| v.downcase },
          lambda { |v| v.upcase }
        )
      end

      it { is_expected.to eq('FOO') }
    end

    describe '#fmap' do
      it 'accepts a proc and lifts the result to Result' do
        expect(subject.fmap(upcase)).to eql(upcased_subject)
      end

      it 'accepts a block too' do
        expect(subject.fmap { |s| s.upcase }).to eql(upcased_subject)
      end

      it 'passes extra arguments to a block' do
        result = subject.fmap(:foo, :bar) do |value, c1, c2|
          expect(value).to eql('foo')
          expect(c1).to eql(:foo)
          expect(c2).to eql(:bar)
          true
        end

        expect(result).to eql(mresult::Success.new(true))
      end

      it 'passes extra arguments to a proc' do
        proc = lambda do |value, c1, c2|
          expect(value).to eql('foo')
          expect(c1).to eql(:foo)
          expect(c2).to eql(:bar)
          true
        end

        result = subject.fmap(proc, :foo, :bar)

        expect(result).to eql(mresult::Success.new(true))
      end
    end

    describe '#or' do
      it 'accepts value as an alternative' do
        expect(subject.or('baz')).to be(subject)
      end

      it 'accepts block as an alternative' do
        expect(subject.or { fail }).to be(subject)
      end

      it 'ignores all values' do
        expect(subject.or(:foo, :bar, :baz) { fail }).to be(subject)
      end
    end

    describe '#or_fmap' do
      it 'accepts value as an alternative' do
        expect(subject.or_fmap('baz')).to be(subject)
      end

      it 'accepts block as an alternative' do
        expect(subject.or_fmap { fail }).to be(subject)
      end

      it 'ignores all values' do
        expect(subject.or_fmap(:foo, :bar, :baz) { fail }).to be(subject)
      end
    end

    describe '#to_result' do
      subject { mresult::Success.new('foo').to_result }

      it 'returns self' do
        is_expected.to eql(mresult::Success.new('foo'))
      end
    end

    describe '#to_maybe' do
      subject { mresult::Success.new('foo').to_maybe }

      it { is_expected.to be_an_instance_of maybe::Some }
      it { is_expected.to eql(some['foo']) }

      context 'value is nil' do
        around { |ex| suppress_warnings { ex.run } }
        subject { mresult::Success.new(nil).to_maybe }

        it { is_expected.to be_an_instance_of maybe::None }
        it { is_expected.to eql(maybe::None.new) }
      end
    end

    describe '#tee' do
      it 'passes through itself when the block returns a Success' do
        expect(subject.tee(->(*) { mresult::Success.new('ignored') })).to eql(subject)
      end

      it 'returns the block result when it is a Failure' do
        expect(subject.tee(->(*) { mresult::Failure.new('failure') }))
          .to be_an_instance_of mresult::Failure
      end
    end

    describe '#value_or' do
      it 'returns existing value' do
        expect(subject.value_or('baz')).to eql(subject.value!)
      end

      it 'ignores a block' do
        expect(subject.value_or { 'baz' }).to eql(subject.value!)
      end
    end

    context 'keyword values' do
      subject { mresult::Success.new(foo: 'foo') }
      let(:struct) { Class.new(Hash)[bar: 'foo'] }

      describe '#bind' do
        it 'passed extra keywords to block along with value' do
          result = subject.bind(bar: 'bar') do |foo:, bar: |
            expect(foo).to eql('foo')
            expect(bar).to eql('bar')
            true
          end

          expect(result).to be true
        end

        it "doesn't use destructuring if it's not needed" do
          expect(success.(struct).bind { |x| x }.class).to be(struct.class)
          expect(success.(struct).bind(nil, bar: 1) { |x| x }.class).to be(struct.class)
        end
      end
    end

    context 'mixed values' do
      subject { mresult::Success.new(foo: 'foo', 'bar' => 'bar') }

      describe '#bind' do
        it 'passed extra keywords to block along with value' do
          result = subject.bind(:baz, quux: 'quux') do |value, baz, quux: |
            expect(value).to eql(subject.value!)
            expect(baz).to eql(:baz)
            expect(quux).to eql('quux')
            true
          end

          expect(result).to be true
        end

        example 'keywords from value takes precedence' do
          result = subject.bind(foo: 'bar', bar: 'bar') do |foo:, bar: |
            expect(foo).to eql('foo')
            expect(bar).to eql('bar')
            true
          end

          expect(result).to be true
        end
      end
    end

    describe '#flip' do
      it 'transforms Success to Failure' do
        expect(subject.flip).to eql(failure['foo'])
      end
    end

    describe '#apply' do
      subject { success[:upcase.to_proc] }

      it 'applies a wrapped function' do
        expect(subject.apply(success['foo'])).to eql(success['FOO'])
        expect(subject.apply(failure['foo'])).to eql(failure['foo'])
      end
    end

    describe '#value!' do
      it 'unwraps the value' do
        expect(subject.value!).to eql('foo')
      end
    end

    describe '#===' do
      it 'matches on the wrapped value' do
        expect(success['foo']).to be === success['foo']
        expect(success[/\w+/]).to be === success['foo']
        expect(success[:bar]).not_to be === success['foo']
        expect(success[10..50]).to be === success[42]
      end
    end
  end

  describe mresult::Failure do
    subject { mresult::Failure.new('bar') }

    it { is_expected.not_to be_success }

    it { is_expected.to be_failure }

    it { is_expected.to eql(described_class.new('bar')) }
    it { is_expected.not_to eql(mresult::Success.new('bar')) }

    it 'dumps to string' do
      expect(subject.to_s).to eql('Failure("bar")')
    end

    it 'has custom inspection' do
      expect(subject.inspect).to eql('Failure("bar")')
    end

    describe '#bind' do
      it 'accepts a proc and returns itself' do
        expect(subject.bind(upcase)).to be subject
      end

      it 'accepts a block and returns itself' do
        expect(subject.bind { |s| s.upcase }).to be subject
      end

      it 'ignores extra arguments' do
        expect(subject.bind(1, 2, 3) { fail }).to be subject
      end
    end

    describe '#result' do
      subject do
        mresult::Failure.new('Foo').result(
          lambda { |v| v.downcase },
          lambda { |v| v.upcase }
        )
      end

      it { is_expected.to eq('foo') }
    end

    describe '#fmap' do
      it 'accepts a proc and returns itself' do
        expect(subject.fmap(upcase)).to be subject
      end

      it 'accepts a block and returns itself' do
        expect(subject.fmap { |s| s.upcase }).to be subject
      end

      it 'ignores arguments' do
        expect(subject.fmap(1, 2, 3) { fail }).to be subject
      end
    end

    describe '#or' do
      it 'accepts a value as an alternative' do
        expect(subject.or('baz')).to eql('baz')
      end

      it 'accepts a block as an alternative' do
        expect(subject.or { 'baz' }).to eql('baz')
      end

      it 'passes extra arguments to a block' do
        result = subject.or(:foo, :bar) do |value, c1, c2|
          expect(value).to eql('bar')
          expect(c1).to eql(:foo)
          expect(c2).to eql(:bar)
          'baz'
        end

        expect(result).to eql('baz')
      end
    end

    describe '#or_fmap' do
      it 'maps an alternative' do
        expect(subject.or_fmap('baz')).to eql(success['baz'])
      end

      it 'accepts a block' do
        expect(subject.or_fmap { 'baz' }).to eql(success['baz'])
      end

      it 'passes extra arguments to a block' do
        result = subject.or_fmap(:foo, :bar) do |value, c1, c2|
          expect(value).to eql('bar')
          expect(c1).to eql(:foo)
          expect(c2).to eql(:bar)
          'baz'
        end

        expect(result).to eql(success['baz'])
      end
    end

    describe '#to_result' do
      let(:subject) { mresult::Failure.new('bar').to_result }

      it 'returns self' do
        is_expected.to eql(mresult::Failure.new('bar'))
      end
    end

    describe '#to_maybe' do
      let(:subject) { mresult::Failure.new('bar').to_maybe }

      it { is_expected.to be_an_instance_of maybe::None }
      it { is_expected.to eql(maybe::None.new) }
    end

    describe '#tee' do
      it 'accepts a proc and returns itself' do
        expect(subject.tee(upcase)).to be subject
      end

      it 'accepts a block and returns itself' do
        expect(subject.tee { |s| s.upcase }).to be subject
      end

      it 'ignores arguments' do
        expect(subject.tee(1, 2, 3) { fail }).to be subject
      end
    end

    describe '#flip' do
      it 'transforms Failure to Success' do
        expect(subject.flip).to eql(success['bar'])
      end
    end

    describe '#value_or' do
      it 'returns passed value' do
        expect(subject.value_or('baz')).to eql('baz')
      end

      it 'executes a block' do
        expect(subject.value_or { |bar| 'foo' + bar }).to eql('foobar')
      end
    end

    describe '#apply' do
      it 'does nothing' do
        expect(subject.apply(success['foo'])).to be(subject)
        expect(subject.apply(failure['foo'])).to be(subject)
      end
    end

    describe '#value!' do
      it 'raises an error' do
        expect { subject.value! }.to raise_error(Dry::Monads::UnwrapError, 'value! was called on Failure("bar")')
      end
    end

    describe '#===' do
      it 'matches using the error value' do
        expect(failure['bar']).to be === subject
        expect(failure[/\w+/]).to be === subject
        expect(failure[String]).to be === subject
        expect(failure['foo']).not_to be === subject
      end
    end
  end
end
