require_relative "store_spec_helper"

describe "Simple::Store.delete!" do
  include StoreSpecHelper

  let!(:record1)  { Simple::Store.create! "Organization", name: "org1" }
  let!(:record2)  { Simple::Store.create! "Organization", name: "org2" }

  context "Simple::Store.delete!(typenames, ids)" do
    it "deletes a single record from the table" do
      deleted_record = Simple::Store.delete! "Organization", 1
      expect(SQL.ask("SELECT COUNT(*) FROM simple_store.organizations")).to eq(1)
      expect(deleted_record.name).to eq("org1")
    end

    it "deletes multiple records from the table" do
      deleted_records = Simple::Store.delete! [ "Organization" ], [1,2]
      expect(SQL.ask("SELECT COUNT(*) FROM simple_store.organizations")).to eq(0)
      expect(deleted_records.map(&:name)).to contain_exactly("org1", "org2")
    end

    context "when deleting a record which no longer exists" do
      before do
        Simple::Store.delete! record1
      end

      it "raises a NotFound error if trying to delete a record which does not exist" do
        expect {
          Simple::Store.delete! [record1]
        }.to raise_error { |e|
          expect(e).to be_a(Simple::Store::RecordNotFound)
        }
      end

      it "Does not delete any records" do
        expect {
          Simple::Store.delete!([record1, record2]) rescue nil
        }.to change {
          SQL.ask("SELECT COUNT(*) FROM simple_store.organizations")
        }.by(0)
      end
    end
  end
  
  context "Simple::Store.delete!(models)" do
    it "deletes a single record from the table" do
      deleted_record = Simple::Store.delete! record1
      expect(SQL.ask("SELECT COUNT(*) FROM simple_store.organizations")).to eq(1)
      expect(deleted_record.name).to eq("org1")
    end

    it "deletes multiple records from the table" do
      deleted_records = Simple::Store.delete! [record1, record2]
      expect(SQL.ask("SELECT COUNT(*) FROM simple_store.organizations")).to eq(0)
      expect(deleted_records.map(&:name)).to contain_exactly("org1", "org2")
    end

    context "when deleting a record which no longer exists" do
      before do
        Simple::Store.delete! record1
      end

      it "raises a NotFound error if trying to delete a record which does not exist" do
        expect {
          Simple::Store.delete! [record1]
        }.to raise_error { |e|
          expect(e).to be_a(Simple::Store::RecordNotFound)
        }
      end

      it "Does not delete any records" do
        expect {
          Simple::Store.delete!([record1, record2]) rescue nil
        }.to change {
          SQL.ask("SELECT COUNT(*) FROM simple_store.organizations")
        }.by(0)
      end
    end
  end

  context "Simple::Store.delete(typenames, ids)" do
    it "deletes a single record from the table" do
      deleted_record = Simple::Store.delete "Organization", 1
      expect(SQL.ask("SELECT COUNT(*) FROM simple_store.organizations")).to eq(1)
      expect(deleted_record.name).to eq("org1")
    end

    it "deletes multiple records from the table" do
      deleted_records = Simple::Store.delete [ "Organization" ], [1,2]
      expect(SQL.ask("SELECT COUNT(*) FROM simple_store.organizations")).to eq(0)
      expect(deleted_records.map(&:name)).to contain_exactly("org1", "org2")
    end

    context "when deleting a record which no longer exists" do
      before do
        Simple::Store.delete record1
      end

      it "Deletes the requested records" do
        Simple::Store.delete([record1, record2]) rescue nil
        expect(SQL.ask("SELECT COUNT(*) FROM simple_store.organizations")).to eq(0)
      end
    end
  end
  
  context "Simple::Store.delete(models)" do
    it "deletes a single record from the table" do
      deleted_record = Simple::Store.delete record1
      expect(SQL.ask("SELECT COUNT(*) FROM simple_store.organizations")).to eq(1)
      expect(deleted_record.name).to eq("org1")
    end

    it "deletes multiple records from the table" do
      deleted_records = Simple::Store.delete [record1, record2]
      expect(SQL.ask("SELECT COUNT(*) FROM simple_store.organizations")).to eq(0)
      expect(deleted_records.map(&:name)).to contain_exactly("org1", "org2")
    end

    context "when deleting a record which no longer exists" do
      before do
        Simple::Store.delete record1
      end

      it "Deletes the requested records" do
        deleted_recs = Simple::Store.delete([record1, record2])
        expect(deleted_recs.map(&:name)).to contain_exactly("org2")
        expect(SQL.ask("SELECT COUNT(*) FROM simple_store.organizations")).to eq(0)
      end
    end
  end

  context "Simple::Store.delete!(<invalid>)" do
    context "when called with wrong no of arguments" do
      it "raises an ArgumentError" do
        expect { Simple::Store.delete! }.to raise_error(ArgumentError)
        expect { Simple::Store.delete! 1, 2, 3 }.to raise_error(ArgumentError)
      end
    end
  end
end
