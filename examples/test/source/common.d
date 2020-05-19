module common;


import hunt.serialization.Common;
import hunt.serialization.JsonSerializer;
import hunt.logging.ConsoleLogger;
import hunt.util.Common;
import hunt.util.ObjectUtils;

import std.conv;
import std.format;
import std.json;
import std.traits;
import std.stdio;
import std.datetime;

struct Plant {
    int number;
    string name;
}

/**
*/
class FruitBase : Cloneable {
    int number;

    string description;

    this() {
        description = "It's the base";
    }

    mixin CloneMemberTemplate!(typeof(this), TopLevel.yes, (typeof(this) from, typeof(this) to) {
        writeln("Checking description. The value is: " ~ from.description);
    });

    override string toString() {
        return "number: " ~ number.to!string() ~ "; description: " ~ description;
    }
}

/**
*/
class Fruit : FruitBase {

    private string name;
    private float price;

    this() {
        name = "unnamed";
        price = 0;
    }

    this(string name, float price) {
        this.name = name;
        this.price = price;
    }

    string getName() {
        return name;
    }

    void setName(string name) {
        this.name = name;
    }

    float getPrice() nothrow {
        return price;
    }

    void setPrice(float price) {
        this.price = price;
    }

    // mixin CloneMemberTemplate!(typeof(this));

    mixin CloneMemberTemplate!(typeof(this), TopLevel.no, (typeof(this) from, typeof(this) to) {
        writefln("Checking name. The last value is: %s", to.name);
        to.name = "name: " ~ from.name;
    });

    override size_t toHash() @trusted nothrow {
        size_t hashcode = 0;
        hashcode = cast(size_t)price * 20;
        hashcode += hashOf(name);
        return hashcode;
    }

    override bool opEquals(Object obj) {
        Fruit pp = cast(Fruit) obj;
        if (pp is null)
            return false;
        return (pp.name == this.name && pp.price == this.price);
    }

    override string toString() {
        return "name: " ~ name ~ "; price: " ~ price.to!string() ~ "; " ~ super.toString;
    }
}


void testClone() {
	Fruit f1 = new Fruit("Apple", 9.5f);
	f1.description = "normal apple";

	Fruit f2 = f1.clone();
	writeln("Cloned fruit: ", f2.toString());

	assert(f1.getName() == f2.getName());
	assert(f1.getPrice() == f2.getPrice());
    // writeln("f1.description: ", f1.description);
    // writeln("f2.description: ", f2.description);
	assert("description: " ~ f1.description == f2.description);
	
	f1.setName("Peach");

	assert(f1.getName() != f2.getName());
}

void testGetFieldValues() {

    import hunt.util.ObjectUtils;
	Fruit f1 = new Fruit("Apple", 9.5f);
	f1.description = "normal apple";

static if (CompilerHelper.isGreaterThan(2086)) {
	trace(f1.getAllFieldValues());
}
}



interface ISettings : JsonSerializable {
    string color();
    void color(string c);
}

abstract class GreetingSettingsBase : ISettings {

    string city;
    string name;

    abstract JSONValue jsonSerialize();
    // JSONValue jsonSerialize() {
    //     JSONValue v;
    //     v["_city"] = city;
    //     return v;
    // }

    void jsonDeserialize(const(JSONValue) value) {
        // do nothing
    }
}

class GreetingSettings : GreetingSettingsBase {
    string _color;

    string name;
    
    this() {
        _color = "black";
    }

    this(string color) {
        _color = color;
    }

    string color() {
        return _color;
    }

    void color(string c) {
        this._color = c;
    }

    override JSONValue jsonSerialize() {
        // return JsonSerializer.serializeObject!(SerializationOptions.Default.traverseBase(false))(this);
        // return JsonSerializer.serializeObject!(SerializationOptions.Default)(this);

        // JSONValue v = super.jsonSerialize();
        JSONValue v;
        v["_city"] = city;
        v["_color"] = _color;
        return v;        
    }
    
    override void jsonDeserialize(const(JSONValue) value) {
        info(value.toString());
        _color = value["_color"].str;
    }

}

class GreetingBase {
    int id;
    private string content;

    this() {

    }

    this(int id, string content) {
        this.id = id;
        this.content = content;
    }

    void setContent(string content) {
        this.content = content;
    }

    string getContent() {
        return this.content;
    }

    override string toString() {
        return "id=" ~ to!string(id) ~ ", content=" ~ content;
    }
}

class Greeting : GreetingBase {
    private string privateMember;
    private ISettings settings;
    Object.Monitor skippedMember;

    alias TestHandler = void delegate(string); 

    // FIXME: Needing refactor or cleanup -@zxp at 6/16/2019, 12:33:02 PM
    // 
    string content; // test for the same fieldname

    SysTime creationTime;
    SysTime[] nullTimes;
    SysTime[] times;
    
    @Ignore // @JsonIgnore
    long currentTime;
    
    byte[] bytes;

    @JsonProperty("Persons")
    string[] members;
    Guest[] guests;
    

    this() {
        super();
        // initialization();
    }

    this(int id, string content) {
        super(id, content);
        this.content = ">>> " ~ content ~ " <<<";
        // initialization();
    }

    void initialization() {

        settings = new GreetingSettings();

        times = new SysTime[2];
        times[0] = Clock.currTime;
        times[1] = Clock.currTime;

        members = new string[2];
        members[0] = "Alice";
        members[1] = "Bob";        

        guests = new Guest[1];
        guests[0] = new Guest();
        guests[0].name = "guest01";


    }

    void addGuest(string name, int age) {

        Guest g = new Guest();
        g.name = name;
        g.age = age;

        guests ~= g;
    }

    void setColor(string color) {
        settings.color = color;
    }

    string getColor() {
        return settings.color();
    }

    void voidReturnMethod() {

    }

    void setPrivateMember(string value) {
        this.privateMember = value;
    }

    string getPrivateMember() {
        return this.privateMember;
    }

    override string toString() {
        string s = format("content=%s, creationTime=%s, currentTime=%s",
                content, creationTime, currentTime);
        return s;
    }
}


class Guest {
    string name;
    int age;
}
