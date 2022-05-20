import SwiftUI

struct ComponentsListRow: Hashable, Identifiable {
    var id: Int { hashValue }
    let name: String
    let isSelected: Bool
    let onSelect: () -> Void

    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(isSelected)
    }

    static func ==(lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }
}

struct ComponentsListSection: Hashable, Identifiable {
    var id: Int { hashValue }

    let name: String
    let rows: [ComponentsListRow]
    let onSelect: () -> Void

    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(rows)
    }

    static func ==(lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }
}

struct ComponentsList: View {
    @State private var filter: String = ""
    let sections: [ComponentsListSection]

    var body: some View {
        VStack(alignment: .leading) {
            FilterView(filter: $filter)
            List {
                if sections.isEmpty {
                    Text("0 components")
                        .foregroundColor(.gray)
                } else {
                    ForEach(sections) { section in
                        let filteredRow = section.rows.filter { filter.isEmpty ? true : $0.name.lowercased().contains(filter.lowercased()) }
                        if !filteredRow.isEmpty {
                            Section {
                                ForEach(filteredRow) { row in
                                    ComponentListItem(
                                        name: row.name,
                                        isSelected: row.isSelected,
                                        onSelect: row.onSelect
                                    )
                                }
                            } header: {
                                HStack {
                                    Text(section.name)
                                        .font(.title.bold())
                                    Button(action: section.onSelect,
                                           label: { Image(systemName: "rectangle.and.pencil.and.ellipsis") })
                                    Spacer()
                                }
                                .padding(.vertical)
                            }
                            Divider()
                        } else {
                            EmptyView()
                        }
                    }
                }
            }
            .frame(minHeight: 200, maxHeight: .infinity)
            .listStyle(SidebarListStyle())
        }
    }
}

struct ComponentsList_Previews: PreviewProvider {
    struct Preview: View {
        var body: some View {
            ComponentsList(sections: [
                .init(name: "DataStore", rows: [
                    .init(name: "WordpressDataStore", isSelected: false, onSelect: {})
                ],
                      onSelect: {}),
                .init(name: "Repository", rows: [
                    .init(name: "WordpressRepository", isSelected: true, onSelect: {})
                ],
                      onSelect: {}),
                .init(name: "Shared", rows: [
                    .init(name: "Networking", isSelected: false, onSelect: {})
                ],
                      onSelect: {})

            ])
        }
    }

    static var previews: some View {
        Preview()
    }
}
