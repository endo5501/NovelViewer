/// Classifies a folder as a "novel folder" versus an "organizational folder".
///
/// A folder is a novel folder if and only if its leaf name (its `folder_name`,
/// e.g. `narou_n1234ab`) is registered in the metadata database. This rule is
/// independent of how deeply the folder is nested within the library, because
/// only the leaf name is ever compared.
bool isNovelFolder(String folderName, Set<String> registeredFolderNames) {
  return registeredFolderNames.contains(folderName);
}
