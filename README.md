# JSONModelAutoMaker
JSONModelAutoMaker

If you are using JSONModel (https://github.com/jsonmodel/jsonmodel) in your iOS Project, and feel tired writing all those subclass of JSONModel, then JSONModelAutoMaker may be your choice to reduce some of your boring work.


# How to use it
JSONModelAutoMaker is a simple tool to generate JsonModel .h and .m file according to your JSON data structure.
It is really easy to use. 
Please see the GIF below.


![alt tag](https://cloud.githubusercontent.com/assets/1708050/23856685/70abb350-0835-11e7-8855-768144f9c36c.gif)


Step 1: Save your JSON to Desktop and name with XXX.json (using txt format) , in the example, I name the file with SomeThing.json. And make sure it is a valid JSON format data (If not, may have something wrong with source file).

Step 2: Run the project and then click "Generate By JsonFile From Desktop".

Step 3: Finish! .h and .m file have generated on Desktop. Using those files in your project and save time to do more creative work!


Tips:

1.You may not satisfied with the name of .h and .m file. Those names are based on the JSON file name, so just name the JSON file you want.

2.I did not include mapping mechanism to the simple tool. So you may find that there are some unproper property name, please rename it.

For example, there is a JSON key named id, some thing like that
    
    "id" : 123

after auto make model, it will be end up with this
    
    @property(nonatomic, strong) NSNumber *id;

because "id" is the keyword of Objective-C, so you may feel uncomfortable with it.


# License

MIT license


# Future

As you see that JSONModelAutoMaker is a really simple and far from a strong tool. If you have any advices or any bug, please leave a message and help me do it better. Thanks~
