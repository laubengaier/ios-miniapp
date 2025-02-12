import SwiftUI
import MiniApp

struct MiniAppSettingsContactsView: View {

    @ObservedObject var viewModel: MiniAppSettingsViewModel

    @State var contacts: [MAContact] = []
    @State var newContact: MAContact?

    var body: some View {
        ZStack {
            List {
                ForEach($contacts, id: \.self) { contact in
                    ContactCellView(name: contact.name ?? "", contactId: contact.id, email: contact.email ?? "")
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle(pageName)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    trackButtonTap(pageName: pageName, buttonTitle: "Add")
                    newContact = viewModel.createRandomContact()
                } label: {
                    Image(systemName: "plus")
                }
                .sheet(item: $newContact, content: { contact in
                    NavigationView {
                        ContactFormView(
                            name: Binding<String>(get: { contact.name ?? "" }, set: { new in newContact?.name = new }),
                            contactId: Binding<String>(get: { contact.id }, set: { new in newContact?.id = new }),
                            email: Binding<String>(get: { contact.email ?? "" }, set: { new in newContact?.email = new }),
                            isPresented: Binding<Bool>(get: { newContact != nil }, set: { new in if !new { newContact = nil } }),
                            onSave: {
                                if let contact = newContact {
                                    contacts.insert(contact, at: 0)
                                    newContact = nil
                                }
                                viewModel.saveContactList(contacts: contacts)
                            }
                        )
                    }
                })
            }
        }
        .onAppear {
            contacts = viewModel.getContacts()
        }
        .trackPage(pageName: pageName)
    }
}

extension MiniAppSettingsContactsView: ViewTrackable {
    var pageName: String {
        return NSLocalizedString("demo.app.rat.page.name.contactslist", comment: "")
    }
}

struct MiniAppSettingsContactsView_Previews: PreviewProvider {
    static var previews: some View {
        MiniAppSettingsContactsView(viewModel: MiniAppSettingsViewModel())
    }
}

extension MiniAppSettingsContactsView {
    struct ContactCellView: View {

        @Binding var name: String
        @Binding var contactId: String
        @Binding var email: String

        var body: some View {
            HStack {
                Circle()
                    .fill(.red)
                    .frame(width: 60, height: 60, alignment: .center)
                    .overlay(Image("profile").foregroundColor(.white))
                VStack(alignment: .leading) {
                    Text(name)
                        .font(.system(size: 14, weight: .bold))
                    Text("Contact ID: \(contactId)")
                        .lineLimit(1)
                    Text("E-Mail address: \(email)")
                }
                .font(.system(size: 13))
            }
            .padding(.vertical, 10)
        }
    }

    struct ContactFormView: View, ViewTrackable {

        @Binding var name: String
        @Binding var contactId: String
        @Binding var email: String
        @Binding var isPresented: Bool

        var onSave: () -> Void

        var body: some View {
            List {
                TextField("Name", text: $name)
                TextField("Contact Id", text: $contactId)
                TextField("Email", text: $email)
            }
            .navigationTitle(pageName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    CloseButton {
                        trackButtonTap(pageName: pageName, buttonTitle: "Close")
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        trackButtonTap(pageName: pageName, buttonTitle: "Save")
                        onSave()
                    } label: {
                        Text("Save")
                    }
                }
            }
        }

        var pageName: String {
            return NSLocalizedString("demo.app.rat.page.name.contactsform", comment: "")
        }
    }
}
