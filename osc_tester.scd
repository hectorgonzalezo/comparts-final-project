
/////////////////////////////////////
//////////// Remember to change the format in ni-mate from Head to /Head!!!!
//////////////////////////////////////////////



(// stores the values of the whole skeleton
~skeleton =Dictionary.new;
~partsSkeleton = ['/Head', '/Neck', '/Torso', '/Right_Shoulder', '/Left_Shoulder', '/Right_Elbow', '/Left_Elbow', '/Right_Hand', 'Left_Hand', '/Right_Knee', '/Left_Knee', '/Right_Foot', '/Left_Foot'];


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

(
//function that reads osc values with inputs for name and a variable to store the value
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
		case
		{msg[1] > ~calibration[sourceName][\xhi]} {~calibration[sourceName][\xhi]= msg[1]}
		{msg[1] < ~calibration[sourceName][\xlo]} {~calibration[sourceName][\xlo] = msg[1]}
		{msg[2] > ~calibration[sourceName][\yhi]} {~calibration[sourceName][\yhi] = msg[2]}
		{msg[2] < ~calibration[sourceName][\ylo]} {~calibration[sourceName][\ylo] = msg[2]}
		{msg[3] > ~calibration[sourceName][\zhi]} {~calibration[sourceName][\zhi] = msg[3]}
		{msg[3] < ~calibration[sourceName][\zlo]} {~calibration[sourceName][\zlo]= msg[3]}

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
(
{
	inf.do{
		~skeleton.collect({ |part| part.postln });
		0.5.wait;
	}
}.fork
)
)



//check calibration values
~calibration.collect({ |i| i.collect({ |in| in.postln})})