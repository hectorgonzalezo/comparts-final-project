
/////////////////////////////////////
//////////// Remember to change the format in ni-mate from Head to /Head  !!!!
//////////////////////////////////////////////



(// stores the values of the whole skeleton
~skeleton =Dictionary.new;
//To calculate the slope
~skeletonPrev =Dictionary.new;
~skeletonSlopes =Dictionary.new;

~partsSkeleton = ['/Head', '/Neck', '/Torso', '/Right_Shoulder', '/Left_Shoulder', '/Right_Elbow', '/Left_Elbow', '/Right_Hand', '/Left_Hand', '/Right_Knee', '/Left_Knee', '/Right_Foot', '/Left_Foot', '/People'];


//nested dictionaries with values used for auto-calibration
~calibration = Dictionary.new;

~calibrationAxis = [\xlo, \xhi, \ylo, \yhi, \zlo, \zhi];
//first nesting
~partsSkeleton.collect({|part| ~calibration[part] =Dictionary.new});
//second nesting
~calibration.collect({
	|part|
	~calibrationAxis.collect({
		|axis|
		//give a diferent value to z
		if(axis.asString.contains("z"),
			{ part.add(axis -> 1)},
			{ part.add(axis -> 0)})
	})
});

//example of use, calibration of low bundary in x axis on head
//~calibration['/Head'][\xlo]
//~skeleton[\head]
(
//function that reads osc values with inputs for name and a variable to store the value
// Symbol (Number) -> OSCdef
~oscReader=
{
	|sourceName, port=7000|
	//functions that grab OSC from certain addresses
	OSCdef(
		sourceName,
		{
			arg msg, time, addr, port;

			//adds the message comming form OSC to the dictionary ~skeleton
			~skeleton[sourceName]= msg;


			//auto-calibration
			if(sourceName != '/People',
				{
					case
					{msg[1] > ~calibration[sourceName][\xhi]} {~calibration[sourceName][\xhi]= msg[1]}
					{msg[1] < ~calibration[sourceName][\xlo]} {~calibration[sourceName][\xlo] = msg[1]}
					{msg[2] > ~calibration[sourceName][\yhi]} {~calibration[sourceName][\yhi] = msg[2]}
					{msg[2] < ~calibration[sourceName][\ylo]} {~calibration[sourceName][\ylo] = msg[2]}
					{msg[3] > ~calibration[sourceName][\zhi]} {~calibration[sourceName][\zhi] = msg[3]}
					{msg[3] < ~calibration[sourceName][\zlo]} {~calibration[sourceName][\zlo]= msg[3]};



					~skeletonSlopes[sourceName]= Array.new(3);

					//start reading slopes only after second iteration
					if(~skeletonPrev[sourceName].notNil,
						{
					//insert the slopes of adjacent values in reading skeleton data
					[1, 2, 3].do{|i|
						~skeletonSlopes[sourceName] =~skeletonSlopes[sourceName].add(
									(~skeleton[sourceName][i] - ~skeletonPrev[sourceName][i]));

					};});
					//stores the value to compare with next one in order to determine slope
					~skeletonPrev[sourceName]= msg;
				},
				{
					if(msg[1].min(1) != ~previousPeople,
						{ ~people = msg[1].min(1);
							~people.postln;

					});
					~previousPeople = msg[1].min(1);
			});


		},
		sourceName,
		nil,
		port
)}

);
//reads from /Torso and stores the value in ~torso
//~oscReader.value('/Torso')

//same for every element of the skeleton
~partsSkeleton.collect({ |part| ~oscReader.value(part)});



//posts the value of the whole dictionary twice a second

Tdef(\valuePoster,
	{
		inf.do{
			//~skeleton.collect({ |part| part.postln });
			//~skeletonSlopes.collect({ |part| part.postln });
			~skeletonSlopes['/Torso'][2].postln;
			0.1.wait;
		}
});

//Tdef(\valuePoster).play

//helps with mapping sounds from the skeleton dictionary to an argument in the sound.
//mapFunc : Symbol String Number Number  Boolean-> Number
// location symbol, axis, lowest value expected, highest value expected, wether value should be mapped linearly.
~mapFunc = {
	|part, axis, lowVal, highVal, linear=true|
	var locArray;
	switch(axis,
		"x", {locArray=1},
		"y", {locArray=2},
		"z", {locArray=3});


	if(linear,{
		~skeleton[part][locArray].linlin(
			~calibration[part][(axis ++ "lo").asSymbol],
			~calibration[part][(axis ++ "hi").asSymbol],
			lowVal,
			highVal)},
	{
		~skeleton[part][locArray].linexp(
			~calibration[part][(axis ++ "lo").asSymbol],
			~calibration[part][(axis ++ "hi").asSymbol],
			lowVal,
			highVal)}
	);

};



//Tdefs that help interact with the soud

Tdef(\interaction,
	{
		inf.do{
			|i|

			~harmProxy.set(
				//Head
				\cutoffFreq, ~mapFunc.value('/Head', "y", 400, 10000),
				\rq, ~mapFunc.value('/Head', "z", 1, 0.01),

				//Torso
				\rate, 1 - (~skeletonSlopes['/Torso'][2] *10),

				//shoulder
				\decayTime, ~mapFunc.value('/Right_Shoulder', "x", 0.1, 2),


				//hand
				\amp, ~mapFunc.value('/Right_Hand', "y", 0, 5),
				\pan, ~mapFunc.value('/Right_Hand', "x", -1, 1),
				\mix, ~mapFunc.value('/Right_Hand', "z", 0.001, 1, false),//false makes it exponential

				//Knee
				\mixMod, ~mapFunc.value('/Right_Knee', "y", 0.8, 1),
				\modSpeed, ~mapFunc.value('/Right_Knee', "x", 30, 500),
				\modLoRange, ~mapFunc.value('/Right_Knee', "z", 30, 500),

				//Foot
				\modHiMul, ~mapFunc.value('/Right_Foot', "x", 1, 3.5),
				\resonanceDecay, ~mapFunc.value('/Right_Foot', "y", 0.1, 1),




			);

			//add delay if slope is positive on right shoulder
			if((~skeletonSlopes['/Right_Shoulder'][2].sign == 1 )&& (~skeletonSlopes['/Right_Shoulder'][2] >= 0.01),
				{
					~harmProxy.set(//shoulder
						\delayTime,  (~skeletonSlopes['/Right_Shoulder'][2] *30))
			},
				{
					~harmProxy.set(//shoulder
						\delayTime,  1)
				}
			);


			~percProxy.set(
				//Head
				\cutoffFreq, ~mapFunc.value('/Head', "y", 500, 15000),
				\rq, ~mapFunc.value('/Head', "z", 1, 0.01),

				//Torso
				\rate, 1 - (~skeletonSlopes['/Torso'][2] *10),

				//shoulder
				\decayTime, ~mapFunc.value('/Left_Shoulder', "x", 2, 0.1),

				//hand
				\amp, ~mapFunc.value('/Left_Hand', "y", 0, 5),
				\pan, ~mapFunc.value('/Left_Hand', "x", -1, 1),
				\mix, ~mapFunc.value('/Left_Hand', "z", 0.001, 1, false),//false makes it exponential

				//Knee
				\mixMod, ~mapFunc.value('/Left_Knee', "y", 1, 0.8),
				\modSpeed, ~mapFunc.value('/Left_Knee', "x", 500, 30),
				\modLoRange, ~mapFunc.value('/Left_Knee', "z", 500, 30),

				//Foot
				\modHiMul, ~mapFunc.value('/Left_Foot', "x", 3.5, 1),
				\resonanceDecay, ~mapFunc.value('/Left_Foot', "y", 0.1, 1),

			);

			if((~skeletonSlopes['/Left_Shoulder'][2].sign == 1 )&& (~skeletonSlopes['/Left_Shoulder'][2] >= 0.01),
				{
					~percProxy.set(//shoulder
						\delayTime,  (~skeletonSlopes['/Left_Shoulder'][2] *20))
			},
				{
					~percProxy.set(//shoulder
						\delayTime,  1)
				});


			0.2.wait;
		}
	}
)
)

