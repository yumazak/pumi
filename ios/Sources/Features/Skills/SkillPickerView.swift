import SwiftUI

struct SkillPickerView: View {
    @Bindable var model: ChatModel
    let skills: [OcSkill]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if skills.isEmpty {
                    ContentUnavailableView("スキルなし", systemImage: "sparkles")
                } else {
                    List(skills) { skill in
                        Button {
                            model.toggleSkill(skill)
                        } label: {
                            HStack(alignment: .top, spacing: 10) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(skill.name ?? skill.id)
                                    if let description = skill.description, !description.isEmpty {
                                        Text(description)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                if model.attachedSkills.contains(where: { $0.id == skill.id }) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.tint)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("スキル")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") { dismiss() }
                }
            }
        }
    }
}
