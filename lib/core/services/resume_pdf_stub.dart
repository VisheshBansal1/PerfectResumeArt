/// Stub for non-web platforms. PDF download is handled via file system.
void downloadPdfOnWeb(List<int> bytes, String fileName) {
  // No-op on mobile/desktop — file is saved and opened via File API
}