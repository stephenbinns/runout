local Color = {}

function Color.Light()
  return { road = '6B6B6B', grass =  'F8B800', rumble =  'CF0B00', lane = 'CCCCCC'  }
end

function Color.Dark()
  return { road = '696969', grass =  'AC7C00', rumble =  'CCCCCC' }
end

function Color.Background()
	return '4428BC'	
end

function Color.Finish()
	return '000000'
end

function Color.Start()
	return 'CCCCCC'
end

return Color