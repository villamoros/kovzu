module FilesHelper
  # Ruta de un archivo adjunto por FilesController. Desde el enlace del taller lleva su token.
  def attachment_file_path(file, disposition: "inline", token: nil)
    attachment = file.respond_to?(:attachment) ? file.attachment : file
    file_path(attachment, disposition: (disposition if disposition == "attachment"), token:)
  end
end
