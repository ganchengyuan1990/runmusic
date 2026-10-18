extends RefCounted
class_name WavStream
## 读取仓库里的 PCM WAV，或在内存里做一段听拍嘀声。
## 不依赖编辑器导入缓存，方便无 .import 时直接塞进 AudioStreamPlayer。


static func load_file(path: String) -> AudioStream:
	if path.is_empty() or not FileAccess.file_exists(path):
		return null
	var ext := path.get_extension().to_lower()
	if ext == "wav":
		return from_wav_file(path)
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is AudioStream:
			return res
	return null


static func from_wav_file(path: String) -> AudioStreamWAV:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("WavStream: cannot open %s" % path)
		return null
	var bytes := file.get_buffer(file.get_length())
	file.close()
	return from_wav_bytes(bytes)


static func from_wav_bytes(bytes: PackedByteArray) -> AudioStreamWAV:
	if bytes.size() < 44:
		return null
	if _ascii(bytes, 0, 4) != "RIFF" or _ascii(bytes, 8, 4) != "WAVE":
		push_warning("WavStream: not a RIFF WAVE")
		return null
	var channels := 1
	var rate := 22050
	var bits := 16
	var data := PackedByteArray()
	var offset := 12
	while offset + 8 <= bytes.size():
		var chunk_id := _ascii(bytes, offset, 4)
		var chunk_size := _u32(bytes, offset + 4)
		var chunk_start := offset + 8
		if chunk_start + chunk_size > bytes.size():
			break
		if chunk_id == "fmt " and chunk_size >= 16:
			var audio_format := _u16(bytes, chunk_start)
			channels = _u16(bytes, chunk_start + 2)
			rate = _u32(bytes, chunk_start + 4)
			bits = _u16(bytes, chunk_start + 14)
			if audio_format != 1:
				push_warning("WavStream: only PCM WAV is supported (format %s)" % audio_format)
				return null
		elif chunk_id == "data":
			data = bytes.slice(chunk_start, chunk_start + chunk_size)
		offset = chunk_start + chunk_size
		if chunk_size % 2 == 1:
			offset += 1
	if data.is_empty() or bits != 16 or (channels != 1 and channels != 2):
		push_warning("WavStream: need 16-bit mono or stereo PCM")
		return null
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = channels == 2
	stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	stream.data = data
	return stream


## 内存里的短嘀声，给校准听拍用。beats 拍，每拍一个 click。
static func make_metronome(bpm: float, beats: int, rate: int = 22050) -> AudioStreamWAV:
	var safe_bpm := maxf(bpm, 40.0)
	var beat_sec := 60.0 / safe_bpm
	var total := int(beat_sec * float(beats) * float(rate))
	var pcm := PackedByteArray()
	pcm.resize(total * 2)
	for beat in beats:
		var start := int(float(beat) * beat_sec * float(rate))
		var freq := 660.0 if beat % 4 == 0 else 880.0
		var amp := 12000.0 if beat % 4 == 0 else 9000.0
		var length := int(0.04 * float(rate))
		for i in length:
			var idx := start + i
			if idx >= total:
				break
			var env := exp(-float(i) / 36.0)
			var sample := int(sin(TAU * freq * float(i) / float(rate)) * amp * env)
			_write_s16(pcm, idx, sample)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	stream.data = pcm
	return stream


static func _write_s16(pcm: PackedByteArray, index: int, sample: int) -> void:
	var value := clampi(sample, -32768, 32767)
	if value < 0:
		value += 65536
	pcm[index * 2] = value & 255
	pcm[index * 2 + 1] = (value >> 8) & 255


static func _ascii(bytes: PackedByteArray, offset: int, count: int) -> String:
	var text := ""
	for i in count:
		text += char(bytes[offset + i])
	return text


static func _u16(bytes: PackedByteArray, offset: int) -> int:
	return bytes[offset] | (bytes[offset + 1] << 8)


static func _u32(bytes: PackedByteArray, offset: int) -> int:
	return bytes[offset] | (bytes[offset + 1] << 8) | (bytes[offset + 2] << 16) | (bytes[offset + 3] << 24)
