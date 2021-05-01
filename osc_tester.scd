l

(
//function that reads osc values with inputs for name and a variable to store the value
~oscReader=
{
	|sourceName, valueVar, port=7000|
//functions that grab OSC from certain addresses
OSCdef(
	sourceName,
	{
		arg msg, time, addr, port;

		msg.postln;
		valueVar=msg

	},
	sourceName,
	nil,
	port
)}


)
//reads from /Torso and stores the value in ~torso
~oscReader.value('/Torso', ~torso)

//posts the value of ~torso twice a second
(
{
	inf.do{
		~torso.postln;
		0.5.wait;
	}
}.fork
)



