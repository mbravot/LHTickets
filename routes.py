@api.route('/tickets/<int:id>/upload', methods=['POST'])
@jwt_required()
def upload_file(id):
    print(f"🔹 Recibida petición: POST /api/tickets/{id}/upload")

    ticket = Ticket.query.get(id)
    if not ticket:
        return jsonify({'message': 'Ticket no encontrado'}), 404

    if 'file' not in request.files:
        return jsonify({'message': 'No se envió ningún archivo'}), 400

    file = request.files['file']

    if file.filename == '':
        return jsonify({'message': 'Nombre de archivo inválido'}), 400

    if not allowed_file(file.filename):
        return jsonify({'message': 'Tipo de archivo no permitido'}), 400

    # Asegurar que la carpeta uploads existe
    upload_folder = 'uploads'
    if not os.path.exists(upload_folder):
        os.makedirs(upload_folder)

    # Generar un nombre único para el archivo
    filename = secure_filename(file.filename)
    file_ext = filename.rsplit('.', 1)[1].lower()
    unique_filename = f"ticket_{id}_{int(time.time())}.{file_ext}"
    file_path = os.path.join(upload_folder, unique_filename)
    
    # Guardar el archivo en el servidor
    file.save(file_path)

    # 🔹 Guardar el nombre del archivo en la base de datos
    try:
        # Obtener la lista actual de archivos adjuntos
        archivos_actuales = ticket.adjunto.split(',') if ticket.adjunto else []
        # Agregar el nuevo archivo a la lista
        archivos_actuales.append(unique_filename)
        # Unir la lista con comas y guardar
        ticket.adjunto = ','.join(archivos_actuales)
        
        db.session.commit()
        print(f"✅ Archivo {unique_filename} guardado en la BD para el ticket {id}")
        return jsonify({'message': 'Archivo subido correctamente', 'adjunto': ticket.adjunto}), 200
    except Exception as e:
        db.session.rollback()
        print(f"🔸 Error al guardar el adjunto en la BD: {str(e)}")
        return jsonify({'error': 'Ocurrió un error al guardar el archivo en la base de datos'}), 500 