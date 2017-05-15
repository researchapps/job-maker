// Input data
var machines = "data/machines.json"


var nav = new Vue({

    el: '#nav',

    data: {
        active: 'generate',
        message: null
    },

    // Functions we will be using.
    methods: {

        makeActive: function(item){
            this.active = item;
        },

    }

})

var cluster = new Vue({

    el: '#main',

    created: function () {
        this.fetchData()
    },

    data: {
        machines: null,
        cluster_name: '',
        script_name: '',
        job_name: '',
        email_address: '',
        time_minutes:0,
        time_hours:0,
        time_seconds:0,
        partition_name:null,
        custom_partition:null,
        number_nodes:1,
        time:'',
        output:' Your script will be displayed here. ',
        errors: 0
    },

    // Functions we will be using.
    methods: {

        // Setup
        fetchData: function () {
            var xhr = new XMLHttpRequest()
            var self = this
            xhr.open('GET', machines)
            xhr.onload = function () {
                self.machines = JSON.parse(xhr.responseText)
            }
            xhr.send()
        },

        // Script Generation
        generateScript: function(){
 
            nav.message = null;
            this.errors = 0;
            this.parseTime();

            if(this.isValid()==true){
                var header = this.writeHeader();
                this.outputScript(header);
            }

            // Scroll the user to the top
            document.body.scrollTop = document.documentElement.scrollTop = 0;

	},

        outputScript: function(content){
	 
            content+='# example: run the job script command line:\n'
            if (this.script_name == ''){
                this.script_name = 'run.job';
            }

            content+='# sbatch  '+(this.script_name)+'\n';
            this.output = content;

        },

        isValid: function() {

              // Any errors from previous functions
              if (this.errors > 0){
                  return false
              }

              if (this.cluster_name == '') {
                  nav.message = 'please select a cluster name to run your job';
                  this.errors+=1
              }

              var choice = this.machines.clusters[this.cluster_name];
              var max_nodes = Number(choice.nodes.maxnnodes);            

              if ((this.number_nodes > max_nodes) || (this.number_nodes < 1)) {
                  if (this.number_nodes < 1) nav.message = 'You must specify at least one node.'
                  else nav.message = 'there are only ' + max_nodes + ' available on '+ this.cluster_name;
                  return false
              }
     
              return true
        },

        parseTime: function(){
	
            hours=Number(this.time_hours).toString();
            minutes=Number(this.time_minutes).toString();
            seconds=Number(this.time_seconds).toString();
            if(this.time_hours<10) hours='0'+hours;
            if(this.time_minutes<10) minutes='0'+minutes;
            if(this.time_seconds<10) seconds='0'+seconds;
            this.time = hours+':'+minutes+':'+seconds;
            if (this.time == "00:00:00"){
                nav.message = 'Please specify a valid time for your job.';
                this.errors+=1;
            }
        },

        generateJump: function() {
            window.scrollTo(0,document.body.scrollHeight);
        },

        updatePartition: function(event) {
            var element = $(event.target)
            var partition_name = $(event.target).val();

            if ($(element).attr('id') == "partition-custom-text"){
                this.partition_name = null;
                this.custom_partition = partition_name
            } 
            this.custom_partition = partition_name
            
        },

        writeHeader: function() {
 
            var header = '#!/bin/bash\n';
            header+='#SBATCH -N '+ this.number_nodes.toString()+'\n';

            if (this.partition_name!=null || this.custom_partition!=null) {
                if (this.custom_partition!=null){
                    header+='#SBATCH -p '+this.custom_partition+'\n';
                } else {
                    header+='#SBATCH -p '+this.partition_name+'\n';
                }
            }

            if (this.job_name!='') {
		header+='#SBATCH -J '+this.job_name+'\n'
            }

            if(this.email_address!=''){
		header+='#SBATCH --mail-user='+this.email_address+'\n'
		header+='#SBATCH --mail-type=ALL\n'
            }

            if(this.time!=''){
                header+='#SBATCH -t '+this.time+'\n'
            }

            header+='\n';
	    return header;

        }

    }


})
