import 'package:diff_match_patch/diff_match_patch.dart';

class MergeHelper {
  /// Merges remote and local content.
  /// If there's a conflict, it inserts Git conflict markers.
  static String merge(String local, String remote) {
    if (local == remote) return local;

    final dmp = DiffMatchPatch();
    
    // We do a character-level diff and then try to patch.
    // However, for "Merging" in a note app, often a simple 
    // line-based merge is what users expect for "conflicts".
    
    // For now, if they are different, we will use a naive approach:
    // If they can be cleanly patched (no overlaps), we do it.
    // If not, we wrap the whole thing in markers or line-by-line.
    
    // If they have common prefix/suffix, we can be smarter.
    // But since notes are small, we can just do a full conflict if they differ significantly.
    
    // Better: Use DMP to find the patches. If any patch fails, it's a conflict.
    final patches = dmp.patch(local, remote);
    final results = dmp.patch_apply(patches, local);
    
    final bool allPatched = results[1].every((element) => element == true);
    
    if (allPatched) {
      return results[0];
    } else {
      // Conflict! Return both with markers.
      return '<<<<<<< LOCAL\n$local\n=======\n$remote\n>>>>>>> REMOTE';
    }
  }

  static bool hasConflicts(String content) {
    return content.contains('<<<<<<< LOCAL') && content.contains('=======');
  }
}
