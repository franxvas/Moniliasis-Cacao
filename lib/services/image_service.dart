import 'package:image_picker/image_picker.dart';

class ImageService {
  ImageService({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  Future<XFile?> takePhoto() => _pickImage(ImageSource.camera);

  Future<XFile?> pickFromGallery() => _pickImage(ImageSource.gallery);

  Future<XFile?> _pickImage(ImageSource source) async {
    final image = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1280,
      maxHeight: 1280,
    );

    if (image == null) {
      return null;
    }

    return image;
  }
}
