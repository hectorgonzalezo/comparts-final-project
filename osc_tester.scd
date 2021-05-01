// stores the values of the whole skeleton
~skeleton =Dictionary.new;
~partsSkeleton = ['/Head', '/Neck', '/Torso', '/Right_Shoulder', '/Left_Shoulder', '/Right_Elbow', '/Left_Elbow', '/Right_Hand', 'Left_Hand', '/Right_Knee', '/Left_Knee', '/Right_Foot', '/Left_Foot'];

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

	},
	sourceName,
	nil,
	port
)}


)
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



