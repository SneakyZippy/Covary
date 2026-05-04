void main() {
  String latestVersion = "1.2.0";
  String currentVersion = "1.2.0+17"; // What if?
  
  List<int> latestParts = latestVersion.split('.').map((e) => int.tryParse(e) ?? 0).toList();
  List<int> currentParts = currentVersion.split('.').map((e) => int.tryParse(e) ?? 0).toList();

  print(latestParts);
  print(currentParts);
  
  bool isHigher = false;
  for (int i = 0; i < latestParts.length && i < currentParts.length; i++) {
      if (latestParts[i] > currentParts[i]) { isHigher = true; break; }
      if (latestParts[i] < currentParts[i]) { isHigher = false; break; }
  }
  if (!isHigher) isHigher = latestParts.length > currentParts.length;
  
  print("isHigher: $isHigher");
}
