// Input data
var machines = "data/machines.json";

fetchData = function () {
    var xhr = new XMLHttpRequest()
    xhr.open('GET', "data/machines.json")
    xhr.onload = function () {
        window.machines = JSON.parse(xhr.responseText)
        var clusters = Object.keys(window.machines)
    }
    xhr.send()
}

fetchData()

var nav = new Vue({

    el: '#nav',

    data: {
        active: 'generate',
        message: null,
        warning: null
    },

    // Functions we will be using.
    methods: {

        makeActive: function(item){
            this.active = item;
            console.log('Beep Boop!');
            $('#robot').show();
            setTimeout(function(){
                $("#robot").hide();
            }, 2000);
        },

    }

})

var cluster = new Vue({

    el: '#main',

    created: function() {
        this.fetchData();
    },

    data: {
        machines: null,
        features: null,
        memory:null,
        qos: null,
        qos_choice: null,
        cluster_name: '',
        script_name: '',
        job_name: '',
        email_address: '',
        output_file:null,
        error_file:null,
        time_minutes:0,
        time_hours:1,
        time_seconds:0,
        partition_name: null,
        number_nodes:1,
        time:'',
        warning: null,
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
                self.clusters = Object.keys(self.machines)
                $.each(self.clusters,function(i,e){ 
                    $("#cluster-select").append('<option value="' + e + '">'+ e + '</option>')
                })
            }
            xhr.send()
        },

        // Script Generation
        generateScript: function(){
 
            // Reset messages
            nav.message = null;
            nav.warning = null;

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
            if (this.job_name == ''){
                this.job_name = 'run';
            }

            content+='# sbatch  '+(this.job_name)+'.job\n';
            this.output = content;

        },

        isValid: function() {
   
              var self = this.$data
              
              // Any errors from previous functions
              if (self.errors > 0){
                  return false
              }

              // A cluster name must be defined
              if (self.cluster_name == '') {
                  nav.message = 'please select a cluster to run your job';
                  return false
              }

              var choice = self.machines[self.cluster_name];

              // If no partition is defined, we use default
              if (self.partition_name == null) {
                  var partition = choice.defaults.partitions[0]
                  nav.warning = 'You did not specify a partition, so the default "' 
                                 + partition + '" will be used.';
              } else {
                  var partition = self.partition_name;
              }

              // Is the memory specified greater than max allowed?
               var max_memory = Number(choice.partitions[partition].MaxMemPerCPU)
               if (this.memory!=null) {
                    if(this.memory > max_memory){
                        nav.warning = 'The max memory for this parition cannot be greater than ' + max_memory + '.'
                        this.memory = max_memory
                    }
               }

              var max_nodes = Number(choice.partitions[partition].maxNodes);            

              if ((self.number_nodes > max_nodes) || (self.number_nodes < 1)) {
                  if (self.number_nodes < 1) nav.message = 'You must specify at least one node.'
                  else nav.message = 'there are only ' + max_nodes + ' available for partition ' + partition;
                  return false
              }
     
              return true
        },

        addFeature: function (event) {
            if (event) {
                var button = $(event.target)
                if (button.hasClass('active')){
                    button.removeClass('active');
                    button.removeClass('feature');
                } else {
                    button.addClass('active');
                    button.addClass('feature');
                }
            }
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

        // When the user selects a cluster, we update partition choices
        updatePartitions: function() {
 
           var self = this.$data
           this.partition_name = null;
           var cluster_name = $("#cluster-select").val();
           var partitions = Object.keys(window.machines[cluster_name]['partitions'])
           $("#partition-select").text(''); 
           $.each(partitions,function(i,e){
               $("#partition-select").append('<option value="' + e + '">'+ e + '</option>')
           })

        },

        // When the user selects a partition, we update feature and qos choices
        selectPartition: function() {
 
           var self = this.$data;
           var choice = self.machines[self.cluster_name];

           // Qos
           var partition_name = $("#partition-select").val() || choice.defaults.partitions[0]
           this.qos = self.machines[self.cluster_name].partitions[partition_name].AllowQos.split(',')

           // Features
           this.features = self.machines[self.cluster_name].features[partition_name]

           //Max memory
           var max_memory = self.machines[self.cluster_name].partitions[partition_name].MaxMemPerCPU
           if (this.memory!=null) {
               this.memory = null;
           }

        },

        writeHeader: function() {
 
            var header = '#!/bin/bash\n';
            header+='#SBATCH --nodes='+ this.number_nodes.toString()+'\n';

            if (this.partition_name!=null) {
                header+='#SBATCH -p '+this.partition_name+'\n';
            }

            if (this.qos_choice!=null) {
                header+='#SBATCH --qos='+this.qos_choice+'\n';
            }

            if (this.memory!=null) {
                header+='#SBATCH --mem='+this.memory+'\n';
            }

            // Add any user features
            var features = $('.feature')
            if (features.length > 0){
                var feature_list = []
                $.each(features,function(e,i){ 
                    var new_feature = $(i).text().trim();
                    feature_list.push(new_feature)
                })
                header+='#SBATCH --constraint="'+feature_list.join('&')+'"\n';
            }

            if (this.job_name!='') {
		header+='#SBATCH --job-name='+this.job_name+'\n'
            }

            if (this.error_file!=null) {
		header+='#SBATCH --error='+this.error_file+'%j.err\n'
            }

            if (this.output_file!=null) {
		header+='#SBATCH --output='+this.output_file+'%j.out\n'
            }

            if(this.email_address!=''){
		header+='#SBATCH --mail-user='+this.email_address+'\n'
		header+='#SBATCH --mail-type=ALL\n'
            }

            if(this.time!=''){
                header+='#SBATCH --time='+this.time+'\n'
            }

            if (this.script_name!=''){
                header+=this.script_name;
            }

            header+='\n';
	    return header;

        }

    }


})
