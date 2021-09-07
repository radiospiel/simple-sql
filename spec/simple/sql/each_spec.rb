require "spec_helper"

describe "Simple::SQL.each" do
  context "when called without a block " do
    it "raises an ArgumentError" do
      expect {
        SQL.each("SELECT id FROM users", into: Hash)
      }.to raise_error(ArgumentError)
    end
  end

  def generate_users!
    1.upto(USER_COUNT).map { create(:user) }
  end
  
  def each!(sql, into: nil)
    @received = nil
    SQL.each(sql, into: into) do |id|
      @received ||= []
      @received << id
    end
  end

  let(:received) { @received }

  describe "each into: nil" do
    before { generate_users! }
    context "when called with matches" do
      it "receives rows as arrays" do
        each! "SELECT id, id FROM users ORDER BY id"

        expect(received).to eq(1.upto(USER_COUNT).map { |i| [ i,i ]})
      end

      it "receives single item row as individual objects" do
        each! "SELECT id FROM users ORDER BY id"

        expect(received).to eq(1.upto(USER_COUNT).to_a)
      end
    end

    context 'when called with no matches' do
      it "does not yield" do
        each! "SELECT id FROM users WHERE FALSE"
        expect(received).to be_nil
      end
    end
  end
  
  describe "each into: <something>" do
    before { generate_users! }

    it "receives rows as Hashes" do
      each! "SELECT id, id AS dupe FROM users ORDER BY id", into: Hash

      expect(received).to eq(1.upto(USER_COUNT).map { |i| { id: i, dupe: i }})
    end

    it "receives rows as immutable" do
      each! "SELECT id, id AS dupe FROM users ORDER BY id", into: :immutable

      expect(received.first.id).to eq(1)
      expect(received[1].dupe).to eq(2)
      expect(received.map(&:class).uniq).to eq([Simple::Immutable])
    end
  end
end
