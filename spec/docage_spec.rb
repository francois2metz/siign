require 'rspec'
require 'siign/docage'

RSpec.describe Siign::Docage do
  let(:faraday) { double }

  describe '#create_full_transaction' do
    it 'create a full transaction' do
      allow(Faraday).to receive(:new).and_return(faraday)
      expect(faraday).to receive(:post).with(
                           '/Transactions/CreateFullTransaction',
                           {
                             Transaction: JSON.generate({
                                                          Name: 'name',
                                                          TransactionFiles: [
                                                            {
                                                              Filename: 'devis-1.pdf',
                                                              FriendlyName: 'Contrat'
                                                            }
                                                          ],
                                                          TransactionMembers: [
                                                            {
                                                              NotifyInvitation: false,
                                                              NotifySignature: false,
                                                              NotifyRefusal: false,
                                                              NotifyCompletion: false,
                                                              FriendlyName: 'Client'
                                                            }
                                                          ],
                                                        }),
                             Client: JSON.generate({
                                                     Email: "francois@example.net",
                                                     FirstName: "2metz",
                                                     LastName: "",
                                                     Address1: "2 avenue de l'observatoire",
                                                     Address2: "",
                                                     City: "PARIS",
                                                     State: "",
                                                     ZipCode: "75000",
                                                     Country: "FRANCE",
                                                     Notes: "",
                                                     Phone: "",
                                                     Mobile: "+33XXXXXXXXX",
                                                     Company: ""
                                                   }),
                             Contrat: be_a_kind_of(Faraday::Multipart::FilePart)
                           }
                         )
      described_class.new('user', 'token').create_full_transaction(
        'name',
        StringIO.new('file'),
        {
          "Email": "francois@example.net",
          "FirstName": "2metz",
          "LastName": "",
          "Address1": "2 avenue de l'observatoire",
          "Address2": "",
          "City": "PARIS",
          "State": "",
          "ZipCode": "75000",
          "Country": "FRANCE",
          "Notes": "",
          "Phone": "",
          "Mobile": "+33XXXXXXXXX",
          "Company": ""
        }
      )
    end
  end

  describe '#get_transaction' do
    it 'returns the transaction' do
      allow(Faraday).to receive(:new).and_return(faraday)
      expect(faraday).to receive(:get).with(
                           '/Transactions/ById/iddocage')

      described_class.new('user', 'token').get_transaction('iddocage')
    end
  end
end
